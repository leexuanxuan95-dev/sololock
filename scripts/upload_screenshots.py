#!/usr/bin/env python3
"""
Upload 5 App Store screenshots for the en-US localization of version 1.0.

Endpoints (all v1):
  GET  /v1/appStoreVersionLocalizations/{loc}/appScreenshotSets
  POST /v1/appScreenshotSets
  POST /v1/appScreenshots
  PUT  <upload-op>                          (chunked)
  PATCH /v1/appScreenshots/{id}            (uploaded=true + checksum)

Try APP_IPHONE_69 first; fall back to APP_IPHONE_67 if Apple rejects the
display class for current SDK.
"""
import hashlib, json, os, sys, time, urllib.error, urllib.request
import jwt

APP_ID         = "6767774134"
VERSION_STRING = "1.0"

ASC_KEY_ID    = "T496HJC8M8"
ASC_ISSUER_ID = "fb385764-17b2-458d-9e8c-0f10c9e185f4"
ASC_KEY_PATH  = "/Users/augis/Downloads/AuthKey_T496HJC8M8.p8"

SCREENSHOT_DIR = "/Users/augis/Desktop/toos/13_SOLOLOCK/fastlane/screenshots/en-US"
# Order matters — App Store displays them left-to-right, top-to-bottom.
# Pick the 5 highest-impact frames.
PICKS = [
    "iPhone_69_01-onboarding.png",
    "iPhone_69_02-picker.png",
    "iPhone_69_05-lock.png",
    "iPhone_69_06-chat.png",
    "iPhone_69_11-paywall.png",
]


def token():
    key = open(ASC_KEY_PATH).read()
    now = int(time.time())
    return jwt.encode({"iss": ASC_ISSUER_ID, "iat": now, "exp": now + 1200,
                       "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256",
                      headers={"kid": ASC_KEY_ID, "typ": "JWT"})


def api(method, path, body=None, expect=(200, 201, 204)):
    url = "https://api.appstoreconnect.apple.com" + path
    data = json.dumps(body).encode() if body else None
    headers = {"Authorization": f"Bearer {token()}"}
    if data: headers["Content-Type"] = "application/json"
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


def find_localization():
    versions = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=10")
    vid = next((v["id"] for v in versions["data"]
                if v["attributes"]["versionString"] == VERSION_STRING), None)
    if not vid:
        print(f"✗ version {VERSION_STRING} not found"); sys.exit(1)
    locs = api("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")
    en = next((l["id"] for l in locs["data"]
               if l["attributes"]["locale"] == "en-US"), None)
    if not en:
        print("✗ en-US localization missing — run asc_finalize.py first"); sys.exit(1)
    return en


def get_or_create_set(loc_id, display_type):
    """Find the existing appScreenshotSet for the given display type, or create one."""
    sets = api("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=20")
    for s in sets.get("data", []):
        if s["attributes"].get("screenshotDisplayType") == display_type:
            return s["id"], False
    body = {"data": {"type": "appScreenshotSets",
                     "attributes": {"screenshotDisplayType": display_type},
                     "relationships": {"appStoreVersionLocalization": {
                         "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}}
    try:
        out = api("POST", "/v1/appScreenshotSets", body=body)
        return out["data"]["id"], True
    except RuntimeError as e:
        print(f"  ✗ couldn't create {display_type}: {e}")
        return None, False


def upload_one(set_id, path):
    file_size = os.path.getsize(path)
    file_name = os.path.basename(path)
    body = {"data": {"type": "appScreenshots",
                     "attributes": {"fileName": file_name, "fileSize": file_size},
                     "relationships": {"appScreenshotSet": {
                         "data": {"type": "appScreenshotSets", "id": set_id}}}}}
    create = api("POST", "/v1/appScreenshots", body=body)
    sid = create["data"]["id"]
    upload_ops = create["data"]["attributes"]["uploadOperations"]

    data = open(path, "rb").read()
    for op in upload_ops:
        offset, length = op["offset"], op["length"]
        chunk = data[offset:offset + length]
        headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                     headers=headers)
        urllib.request.urlopen(req).read()

    checksum = hashlib.md5(data).hexdigest()
    body = {"data": {"type": "appScreenshots", "id": sid,
                     "attributes": {"uploaded": True, "sourceFileChecksum": checksum}}}
    api("PATCH", f"/v1/appScreenshots/{sid}", body=body)
    return sid


def main():
    loc_id = find_localization()
    print(f"  localization id: {loc_id}")

    # Try the 6.9" type first; some SDK builds want APP_IPHONE_67 even for 1320×2868.
    for display_type in ("APP_IPHONE_69", "APP_IPHONE_67"):
        set_id, created = get_or_create_set(loc_id, display_type)
        if set_id is None:
            continue
        print(f"  using set {set_id} ({display_type}, {'new' if created else 'existing'})")
        for fname in PICKS:
            path = os.path.join(SCREENSHOT_DIR, fname)
            if not os.path.isfile(path):
                print(f"    ✗ missing {fname}")
                continue
            try:
                sid = upload_one(set_id, path)
                print(f"    ✓ uploaded {fname} (id {sid[:12]}…)")
            except RuntimeError as e:
                print(f"    ✗ {fname}: {str(e)[:300]}")
        return  # success on first display type that worked
    print("✗ no display type accepted — Apple may not support either yet"); sys.exit(1)


if __name__ == "__main__":
    main()
