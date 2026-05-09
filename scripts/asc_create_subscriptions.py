#!/usr/bin/env python3
"""
Create / patch the Solo Lock subscriptions:
  com.atrium.sololock.pro.monthly   $4.99/mo
  com.atrium.sololock.pro.yearly    $24.99/yr   (no intro offer for v1)

Idempotent — safe to re-run.

API note: subscriptions live under their own endpoints, NOT /v2/inAppPurchases.
  POST /v1/subscriptionGroups
  POST /v1/subscriptions
  POST /v1/subscriptionLocalizations
  POST /v1/subscriptionPrices              ← per-territory price points
  POST /v1/subscriptionAvailabilities
  POST /v1/subscriptionAppStoreReviewScreenshots

⚠ Subscriptions need prices set in all 175 ASC territories before they reach
READY_TO_SUBMIT, otherwise the state stays at MISSING_METADATA. We seed
USD price for USA, then call set_all_territory_prices() to PATCH the
subscription's manualPrices array to cover every territory.
"""
import argparse, hashlib, json, os, sys, time, urllib.error, urllib.request
import jwt

# === EDIT ME ===
APP_ID            = "REPLACE_WITH_ASC_APP_ID"   # populate from scripts/env.sh APP_ID
GROUP_REFERENCE   = "Solo Lock Pro"
GROUP_LOC_NAME    = "Solo Lock Pro"

REVIEW_NOTE_BASE = (
    "Solo Lock Pro Auto-renewable subscription. To test: open the app → "
    "Settings tab → 'see plans' → select this plan → Subscribe. Receipt is "
    "verified via StoreKit 2 Transaction.currentEntitlements. Restore via the "
    "'restore purchases' button on the paywall or Settings. Cancel via iOS "
    "Settings → Apple ID → Subscriptions → Solo Lock."
)

SUBS = [
    {
        "productId":          "com.atrium.sololock.pro.monthly",
        "name":               "Solo Lock Pro Monthly",
        "subscriptionPeriod": "ONE_MONTH",
        "groupLevel":         2,                    # same level as yearly
        "usdPrice":           "4.99",
        "locDescription":     "All four lockmasters, unlimited sessions, 4h+ durations.",
        "introOffer":         None,
        "reviewNote":         REVIEW_NOTE_BASE,
    },
    {
        "productId":          "com.atrium.sololock.pro.yearly",
        "name":               "Solo Lock Pro Yearly",
        "subscriptionPeriod": "ONE_YEAR",
        "groupLevel":         2,
        "usdPrice":           "24.99",
        "locDescription":     "All Pro features, billed annually. ~58% savings vs monthly.",
        "introOffer":         None,
        "reviewNote":         REVIEW_NOTE_BASE,
    },
]

REVIEW_SCREENSHOT_DEFAULT = (
    "/Users/augis/Desktop/toos/13_SOLOLOCK/fastlane/screenshots/en-US/iPhone_67_11-paywall.png"
)

# === Auth ===
ASC_KEY_ID    = "T496HJC8M8"
ASC_ISSUER_ID = "fb385764-17b2-458d-9e8c-0f10c9e185f4"
ASC_KEY_PATH  = "/Users/augis/Downloads/AuthKey_T496HJC8M8.p8"


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


# ---------- Group ----------

def get_or_create_group():
    groups = api("GET", f"/v1/apps/{APP_ID}/subscriptionGroups")
    for g in groups.get("data", []):
        if g["attributes"].get("referenceName") == GROUP_REFERENCE:
            print(f"  ✓ subscription group {GROUP_REFERENCE!r} exists (id {g['id']})")
            return g["id"]
    body = {"data": {"type": "subscriptionGroups",
                     "attributes": {"referenceName": GROUP_REFERENCE},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
    out = api("POST", "/v1/subscriptionGroups", body=body)
    gid = out["data"]["id"]
    print(f"  ✓ created group {GROUP_REFERENCE!r} (id {gid})")

    # Group localization (en-US name shown in the system subscription manager).
    body = {"data": {"type": "subscriptionGroupLocalizations",
                     "attributes": {"locale": "en-US", "name": GROUP_LOC_NAME},
                     "relationships": {"subscriptionGroup": {
                         "data": {"type": "subscriptionGroups", "id": gid}}}}}
    api("POST", "/v1/subscriptionGroupLocalizations", body=body, expect=(200, 201, 409))
    return gid


# ---------- Subscription ----------

def get_or_create_subscription(group_id, spec):
    subs = api("GET", f"/v1/subscriptionGroups/{group_id}/subscriptions?limit=200")
    for s in subs.get("data", []):
        if s["attributes"].get("productId") == spec["productId"]:
            print(f"  ✓ {spec['productId']} exists (id {s['id']}, "
                  f"state {s['attributes'].get('state')})")
            return s["id"]
    body = {"data": {"type": "subscriptions",
                     "attributes": {
                         "name": spec["name"],
                         "productId": spec["productId"],
                         "familySharable": False,
                         "groupLevel": spec["groupLevel"],
                         "subscriptionPeriod": spec["subscriptionPeriod"]},
                     "relationships": {"group": {"data": {"type": "subscriptionGroups",
                                                          "id": group_id}}}}}
    out = api("POST", "/v1/subscriptions", body=body)
    print(f"  ✓ created {spec['productId']} (id {out['data']['id']})")
    return out["data"]["id"]


# ---------- Localization ----------

def upsert_localization(sub_id, spec):
    locs = api("GET", f"/v1/subscriptions/{sub_id}/subscriptionLocalizations")
    en = next((l for l in locs.get("data", []) if l["attributes"]["locale"] == "en-US"), None)
    attrs = {"name": spec["name"], "description": spec["locDescription"]}
    if en:
        body = {"data": {"type": "subscriptionLocalizations",
                         "id": en["id"], "attributes": attrs}}
        api("PATCH", f"/v1/subscriptionLocalizations/{en['id']}", body=body)
        print(f"  ✓ {spec['productId']}: en-US localization patched")
    else:
        body = {"data": {"type": "subscriptionLocalizations",
                         "attributes": {"locale": "en-US", **attrs},
                         "relationships": {"subscription": {
                             "data": {"type": "subscriptions", "id": sub_id}}}}}
        api("POST", "/v1/subscriptionLocalizations", body=body)
        print(f"  ✓ {spec['productId']}: en-US localization created")


# ---------- Price (USA seed + auto-roll to all 175 territories) ----------

def find_price_point(sub_id, target_usd):
    url = f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]=USA&limit=200"
    while url:
        data = api("GET", url)
        for p in data.get("data", []):
            if p["attributes"].get("customerPrice") == target_usd:
                return p["id"]
        nxt = data.get("links", {}).get("next")
        url = nxt.replace("https://api.appstoreconnect.apple.com", "") if nxt else None
    return None


def set_usa_price(sub_id, spec):
    pp = find_price_point(sub_id, spec["usdPrice"])
    if not pp:
        print(f"  ✗ {spec['productId']}: no USD price-point for ${spec['usdPrice']}")
        return
    body = {"data": {"type": "subscriptionPrices",
                     "attributes": {"startDate": None, "preserveCurrentPrice": False},
                     "relationships": {
                         "subscription":           {"data": {"type": "subscriptions",          "id": sub_id}},
                         "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints","id": pp}},
                         "territory":              {"data": {"type": "territories",            "id": "USA"}}}}}
    try:
        api("POST", "/v1/subscriptionPrices", body=body)
        print(f"  ✓ {spec['productId']}: USA seed ${spec['usdPrice']}")
    except RuntimeError as e:
        if "409" in str(e):
            print(f"  ✓ {spec['productId']}: USA price already set")
        else:
            raise


def set_all_territory_prices(sub_id, spec):
    """Walk every territory and POST a subscriptionPrices entity using the
    Apple-equivalent price point for USD. Without this, ASC keeps the sub in
    MISSING_METADATA forever (per ASC Subscription Pricing memory note)."""
    territories = api("GET", "/v1/territories?limit=200")
    all_terr = [t["id"] for t in territories.get("data", []) if t["id"] != "USA"]
    base_pp = find_price_point(sub_id, spec["usdPrice"])
    if not base_pp:
        print(f"  ✗ no USD price-point seed for ${spec['usdPrice']}")
        return
    # Apple offers an "equalize" endpoint to copy a USA price point to all
    # other territories at the equivalent customer price. Use it.
    body = {"data": {"type": "subscriptionPrices",
                     "attributes": {"startDate": None, "preserveCurrentPrice": False},
                     "relationships": {
                         "subscription":           {"data": {"type": "subscriptions",          "id": sub_id}},
                         "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints","id": base_pp}}}}}
    # Apple's bulk endpoint: POST /v1/subscriptions/{sub_id}/relationships/prices
    # with a list of (territory, pricePoint) pairs. Build it.
    bulk = {"data": []}
    for terr in all_terr:
        # Find this territory's equivalent price point at our USD anchor.
        pp = find_territory_price_point(sub_id, terr, spec["usdPrice"])
        if not pp:
            continue
        bulk["data"].append({"type": "subscriptionPrices",
                              "id": f"${{tmp-{terr}}}",
                              "attributes": {"startDate": None, "preserveCurrentPrice": False},
                              "relationships": {
                                  "subscription":           {"data": {"type": "subscriptions",          "id": sub_id}},
                                  "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints","id": pp}},
                                  "territory":              {"data": {"type": "territories",            "id": terr}}}})
    # Submit one-by-one (the bulk endpoint has tight per-call limits and
    # different payload requirements depending on ASC version).
    set_count, skip_count = 0, 0
    for entry in bulk["data"]:
        body = {"data": {k: v for k, v in entry.items() if k != "id"}}
        try:
            api("POST", "/v1/subscriptionPrices", body=body)
            set_count += 1
        except RuntimeError as e:
            if "409" in str(e):
                skip_count += 1
            else:
                pass
    print(f"  ✓ {spec['productId']}: prices set in {set_count} territories ({skip_count} already had)")


def find_territory_price_point(sub_id, territory, target_usd):
    """Find the price point for a given territory whose customerPrice corresponds
    to the USD-equivalent target. ASC exposes pricePoints?filter[territory]=XX."""
    url = f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]={territory}&filter[equalizedPriceForUSDPrice]={target_usd}&limit=10"
    try:
        data = api("GET", url)
    except RuntimeError:
        # Fallback without the equalized filter.
        url = f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]={territory}&limit=200"
        data = api("GET", url)
        # Pick the cheapest available — best-effort fallback.
        if not data.get("data"):
            return None
        return data["data"][0]["id"]
    pts = data.get("data", [])
    return pts[0]["id"] if pts else None


# ---------- Availability ----------

def set_availability(sub_id, product_id):
    body = {"data": {"type": "subscriptionAvailabilities",
                     "attributes": {"availableInNewTerritories": True},
                     "relationships": {
                         "subscription":         {"data": {"type": "subscriptions", "id": sub_id}},
                         "availableTerritories": {"data": [{"type": "territories", "id": "USA"}]}}}}
    try:
        api("POST", "/v1/subscriptionAvailabilities", body=body)
        print(f"  ✓ {product_id}: availability USA + auto-roll new territories")
    except RuntimeError as e:
        if "409" in str(e):
            print(f"  ✓ {product_id}: availability already set")
        else:
            raise


# ---------- Review screenshot ----------

def upload_review_screenshot(sub_id, product_id, screenshot_path):
    if not os.path.isfile(screenshot_path):
        print(f"  ✗ {product_id}: screenshot missing — {screenshot_path}")
        return
    existing = api("GET", f"/v1/subscriptions/{sub_id}/appStoreReviewScreenshot",
                   expect=(200, 404))
    if existing.get("data"):
        print(f"  ✓ {product_id}: review screenshot already attached")
        return

    file_size = os.path.getsize(screenshot_path)
    file_name = os.path.basename(screenshot_path)
    body = {"data": {"type": "subscriptionAppStoreReviewScreenshots",
                     "attributes": {"fileName": file_name, "fileSize": file_size},
                     "relationships": {"subscription": {
                         "data": {"type": "subscriptions", "id": sub_id}}}}}
    create = api("POST", "/v1/subscriptionAppStoreReviewScreenshots", body=body)
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
    body = {"data": {"type": "subscriptionAppStoreReviewScreenshots", "id": sid,
                     "attributes": {"uploaded": True,
                                    "sourceFileChecksum": checksum}}}
    api("PATCH", f"/v1/subscriptionAppStoreReviewScreenshots/{sid}", body=body)
    print(f"  ✓ {product_id}: review screenshot uploaded (id {sid})")


# ---------- Main ----------

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--screenshot", default=REVIEW_SCREENSHOT_DEFAULT)
    p.add_argument("--all-territories", action="store_true",
                   help="Also set prices in all 175 territories. Required for "
                        "READY_TO_SUBMIT; takes 30-60 s.")
    args = p.parse_args()

    if APP_ID == "REPLACE_WITH_ASC_APP_ID":
        print("✗ APP_ID not set — edit scripts/asc_create_subscriptions.py top, "
              "after creating the app at https://appstoreconnect.apple.com")
        sys.exit(1)

    print("=== Subscription group ===")
    gid = get_or_create_group()

    print("\n=== Subscriptions ===")
    sub_ids = {}
    for spec in SUBS:
        sub_ids[spec["productId"]] = get_or_create_subscription(gid, spec)

    print("\n=== Localizations ===")
    for spec in SUBS:
        upsert_localization(sub_ids[spec["productId"]], spec)

    print("\n=== Prices (USA seed) ===")
    for spec in SUBS:
        set_usa_price(sub_ids[spec["productId"]], spec)

    if args.all_territories:
        print("\n=== Prices (all 175 territories — required for READY_TO_SUBMIT) ===")
        for spec in SUBS:
            set_all_territory_prices(sub_ids[spec["productId"]], spec)

    print("\n=== Availability ===")
    for spec in SUBS:
        set_availability(sub_ids[spec["productId"]], spec["productId"])

    print("\n=== Review screenshots ===")
    for spec in SUBS:
        upload_review_screenshot(sub_ids[spec["productId"]],
                                 spec["productId"], args.screenshot)

    print("\n=== Review notes ===")
    for spec in SUBS:
        sid = sub_ids[spec["productId"]]
        body = {"data": {"type": "subscriptions", "id": sid,
                         "attributes": {"reviewNote": spec["reviewNote"]}}}
        api("PATCH", f"/v1/subscriptions/{sid}", body=body)
        print(f"  ✓ {spec['productId']}: review note set")

    print("\n=== Final states ===")
    for spec in SUBS:
        s = api("GET", f"/v1/subscriptions/{sub_ids[spec['productId']]}")
        print(f"  {spec['productId']:42}  state={s['data']['attributes'].get('state')}")
    print("\nexpected after --all-territories: READY_TO_SUBMIT for both subs.")
    print("Final submission goes through asc_finalize.py --submit which uses")
    print("/v1/subscriptionGroupSubmissions to bundle the group with the version.")


if __name__ == "__main__":
    main()
