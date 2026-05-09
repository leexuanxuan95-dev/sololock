#!/usr/bin/env python3
"""
Create / patch the Solo Lock NON_CONSUMABLE in-app purchase:
  com.atrium.sololock.pro.lifetime   $59 one-time

Idempotent — safe to re-run.

Endpoints used (all v1/v2 ASC API):
  POST  /v2/inAppPurchases
  POST  /v2/inAppPurchaseLocalizations
  POST  /v1/inAppPurchasePriceSchedules
  POST  /v1/inAppPurchaseAvailabilities
  POST  /v1/inAppPurchaseAppStoreReviewScreenshots
  PATCH /v2/inAppPurchases/{id}                     (review note)

Per IAP Submission Endpoints memory: a NON_CONSUMABLE that is the very first
IAP for an app must be submitted alongside the version (handled by
asc_finalize.py --submit). For subsequent IAPs, use:
  POST /v1/inAppPurchaseSubmissions
"""
import argparse, hashlib, json, os, sys, time, urllib.error, urllib.request
import jwt

# === EDIT ME PER IAP ===
APP_ID            = "REPLACE_WITH_ASC_APP_ID"   # populate from scripts/env.sh APP_ID
PRODUCT_ID        = "com.atrium.sololock.pro.lifetime"
REFERENCE_NAME    = "Solo Lock Pro Lifetime"
IAP_TYPE          = "NON_CONSUMABLE"
USD_PRICE         = "59.00"

DISPLAY_NAME      = "Solo Lock Pro · Lifetime"
DESCRIPTION       = ("Pay once, every Pro feature forever. All four lockmasters, "
                     "unlimited sessions per day, 4h / 8h / overnight durations, "
                     "Live Activity, Apple Watch, history insights.")
REVIEW_NOTE       = (
    "Solo Lock Pro Lifetime: NON_CONSUMABLE, one-time $59 unlock for all Pro "
    "features. To test: open the app → tap Settings tab → tap 'see plans' → "
    "Lifetime tier → Subscribe. The receipt is verified via StoreKit 2 "
    "Transaction.currentEntitlements; the entitlement persists across launches "
    "and across reinstalls (restore via the 'restore purchases' button on the "
    "paywall or in Settings)."
)

# === Auth ===
ASC_KEY_ID    = "T496HJC8M8"
ASC_ISSUER_ID = "fb385764-17b2-458d-9e8c-0f10c9e185f4"
ASC_KEY_PATH  = "/Users/augis/Downloads/AuthKey_T496HJC8M8.p8"

REVIEW_SCREENSHOT_DEFAULT = (
    "/Users/augis/Desktop/toos/13_SOLOLOCK/fastlane/screenshots/en-US/iPhone_67_11-paywall.png"
)


def token():
    key = open(ASC_KEY_PATH).read()
    now = int(time.time())
    return jwt.encode({"iss": ASC_ISSUER_ID, "iat": now, "exp": now + 1200,
                       "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256",
                      headers={"kid": ASC_KEY_ID, "typ": "JWT"})


def api(method, path, *, body=None, expect=(200, 201, 204)):
    url = "https://api.appstoreconnect.apple.com" + path
    data = json.dumps(body).encode() if body else None
    headers = {"Authorization": f"Bearer {token()}"}
    if data:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            payload = r.read()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        if e.code in expect:
            try: return json.loads(body) if body else {}
            except: return {}
        raise RuntimeError(f"{method} {path} → {e.code}: {body[:600]}")


# ---------- IAP ----------

def get_or_create_iap():
    iaps = api("GET", f"/v2/apps/{APP_ID}/inAppPurchases?limit=200")
    for d in iaps.get("data", []):
        if d["attributes"].get("productId") == PRODUCT_ID:
            print(f"  ✓ {PRODUCT_ID} exists (id {d['id']}, state {d['attributes'].get('state')})")
            return d["id"]
    body = {"data": {"type": "inAppPurchases",
                     "attributes": {"name": REFERENCE_NAME,
                                    "productId": PRODUCT_ID,
                                    "inAppPurchaseType": IAP_TYPE,
                                    "reviewNote": REVIEW_NOTE,
                                    "familySharable": False},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
    out = api("POST", "/v2/inAppPurchases", body=body)
    print(f"  ✓ created {PRODUCT_ID} (id {out['data']['id']})")
    return out["data"]["id"]


# ---------- Localization ----------

def upsert_localization(iap_id):
    locs = api("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")
    en = next((l for l in locs.get("data", []) if l["attributes"]["locale"] == "en-US"), None)
    attrs = {"name": DISPLAY_NAME, "description": DESCRIPTION}
    if en:
        body = {"data": {"type": "inAppPurchaseLocalizations", "id": en["id"], "attributes": attrs}}
        api("PATCH", f"/v1/inAppPurchaseLocalizations/{en['id']}", body=body)
        print(f"  ✓ en-US localization patched")
    else:
        body = {"data": {"type": "inAppPurchaseLocalizations",
                         "attributes": {"locale": "en-US", **attrs},
                         "relationships": {"inAppPurchaseV2": {
                             "data": {"type": "inAppPurchases", "id": iap_id}}}}}
        api("POST", "/v1/inAppPurchaseLocalizations", body=body)
        print(f"  ✓ en-US localization created")


# ---------- Price ----------

def find_price_point(iap_id, target_usd):
    url = f"/v1/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200"
    while url:
        data = api("GET", url)
        for p in data.get("data", []):
            if p["attributes"].get("customerPrice") == target_usd:
                return p["id"]
        nxt = data.get("links", {}).get("next")
        url = nxt.replace("https://api.appstoreconnect.apple.com", "") if nxt else None
    return None


def set_price(iap_id):
    # Check if a schedule already exists.
    existing = api("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule",
                   expect=(200, 404))
    if existing.get("data"):
        print(f"  ✓ price schedule already exists")
        return
    pp = find_price_point(iap_id, USD_PRICE)
    if not pp:
        print(f"  ✗ no USD price-point for ${USD_PRICE}")
        return
    body = {"data": {"type": "inAppPurchasePriceSchedules",
                     "relationships": {
                         "inAppPurchase":  {"data": {"type": "inAppPurchases", "id": iap_id}},
                         "baseTerritory":  {"data": {"type": "territories", "id": "USA"}},
                         "manualPrices":   {"data": [{"type": "inAppPurchasePrices", "id": "${price-1}"}]},
                         "automaticPrices":{"data": []}}},
            "included": [{"type": "inAppPurchasePrices", "id": "${price-1}",
                          "attributes": {"startDate": None},
                          "relationships": {
                              "inAppPurchasePricePoint": {
                                  "data": {"type": "inAppPurchasePricePoints", "id": pp}},
                              "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}}}}]}
    api("POST", "/v1/inAppPurchasePriceSchedules", body=body)
    print(f"  ✓ price schedule created (USD ${USD_PRICE} base, auto-derive other territories)")


# ---------- Availability ----------

def set_availability(iap_id):
    existing = api("GET", f"/v2/inAppPurchases/{iap_id}/iapAvailability",
                   expect=(200, 404))
    if existing.get("data"):
        print(f"  ✓ availability already set")
        return
    # All 175 territories (Apple's "auto-roll new territories" + USA seed).
    body = {"data": {"type": "inAppPurchaseAvailabilities",
                     "attributes": {"availableInNewTerritories": True},
                     "relationships": {
                         "inAppPurchase":        {"data": {"type": "inAppPurchases", "id": iap_id}},
                         "availableTerritories": {"data": [{"type": "territories", "id": "USA"}]}}}}
    try:
        api("POST", "/v1/inAppPurchaseAvailabilities", body=body)
        print(f"  ✓ availability USA + auto-roll new territories")
    except RuntimeError as e:
        if "409" in str(e):
            print(f"  ✓ availability already set")
        else:
            raise


# ---------- Review screenshot ----------

def upload_review_screenshot(iap_id, screenshot_path):
    if not os.path.isfile(screenshot_path):
        print(f"  ✗ screenshot missing: {screenshot_path}")
        print(f"     run scripts/screenshots.sh first")
        sys.exit(1)
    existing = api("GET", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot",
                   expect=(200, 404))
    if existing.get("data"):
        print(f"  ✓ review screenshot already attached")
        return

    file_size = os.path.getsize(screenshot_path)
    file_name = os.path.basename(screenshot_path)
    body = {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
                     "attributes": {"fileName": file_name, "fileSize": file_size},
                     "relationships": {"inAppPurchaseV2": {
                         "data": {"type": "inAppPurchases", "id": iap_id}}}}}
    create = api("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", body=body)
    sid = create["data"]["id"]
    upload_ops = create["data"]["attributes"]["uploadOperations"]

    data = open(screenshot_path, "rb").read()
    for op in upload_ops:
        offset, length = op["offset"], op["length"]
        chunk = data[offset:offset + length]
        headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                     headers=headers)
        urllib.request.urlopen(req).read()

    checksum = hashlib.md5(data).hexdigest()
    body = {"data": {"type": "inAppPurchaseAppStoreReviewScreenshots",
                     "id": sid,
                     "attributes": {"uploaded": True, "sourceFileChecksum": checksum}}}
    api("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{sid}", body=body)
    print(f"  ✓ review screenshot uploaded (id {sid})")


# ---------- Main ----------

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--screenshot", default=REVIEW_SCREENSHOT_DEFAULT,
                   help="Path to the paywall PNG to attach as IAP review proof.")
    args = p.parse_args()

    if APP_ID == "REPLACE_WITH_ASC_APP_ID":
        print("✗ APP_ID not set — edit scripts/asc_create_iap.py top, "
              "after creating the app at https://appstoreconnect.apple.com")
        sys.exit(1)

    print(f"=== {PRODUCT_ID} ===")
    iap_id = get_or_create_iap()
    upsert_localization(iap_id)
    set_price(iap_id)
    set_availability(iap_id)
    upload_review_screenshot(iap_id, args.screenshot)

    final = api("GET", f"/v2/inAppPurchases/{iap_id}")
    print(f"\nfinal state: {final['data']['attributes'].get('state')}")
    print("expected: READY_TO_SUBMIT  (will be bundled into version submission "
          "via asc_finalize.py --submit)")


if __name__ == "__main__":
    main()
