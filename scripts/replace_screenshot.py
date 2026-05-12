#!/usr/bin/env python3
"""
Replace the App Store paywall screenshot.

ASC's /v1/appScreenshots doesn't allow PATCH of the file blob — you delete
and re-upload. This script:
  1. Finds the existing screenshot set (APP_IPHONE_67) for en-US
  2. Lists screenshots in it
  3. Deletes the one whose filename includes "11-paywall"
  4. Uploads the fresh iPhone_69_11-paywall.png in its place
"""
import hashlib, json, os, sys, time, urllib.error, urllib.request
import jwt

APP_ID         = "6767774134"
VERSION_STRING = "1.0"
LOCAL_FILE     = "/Users/augis/Desktop/toos/13_SOLOLOCK/fastlane/screenshots/en-US/iPhone_69_11-paywall.png"

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


def main():
    # Locate localization
    versions = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=10")
    vid = next(v["id"] for v in versions["data"]
               if v["attributes"]["versionString"] == VERSION_STRING)
    locs = api("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")
    loc_id = next(l["id"] for l in locs["data"]
                  if l["attributes"]["locale"] == "en-US")
    print(f"  localization: {loc_id}")

    # Find the 6.7" screenshot set
    sets = api("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?limit=20")
    set_id = next(s["id"] for s in sets["data"]
                  if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67")
    print(f"  set: {set_id}")

    # List its screenshots, find the paywall one
    shots = api("GET", f"/v1/appScreenshotSets/{set_id}/appScreenshots?limit=20")
    paywall_id = None
    for s in shots["data"]:
        n = s["attributes"].get("fileName", "")
        print(f"    found: {n} (id {s['id'][:12]}…)")
        if "11-paywall" in n or "paywall" in n.lower():
            paywall_id = s["id"]

    if paywall_id:
        api("DELETE", f"/v1/appScreenshots/{paywall_id}")
        print(f"  ✓ deleted old paywall {paywall_id[:12]}…")

    # Upload the fresh one
    file_size = os.path.getsize(LOCAL_FILE)
    file_name = os.path.basename(LOCAL_FILE)
    body = {"data": {"type": "appScreenshots",
                     "attributes": {"fileName": file_name, "fileSize": file_size},
                     "relationships": {"appScreenshotSet": {
                         "data": {"type": "appScreenshotSets", "id": set_id}}}}}
    create = api("POST", "/v1/appScreenshots", body=body)
    sid = create["data"]["id"]
    upload_ops = create["data"]["attributes"]["uploadOperations"]

    data = open(LOCAL_FILE, "rb").read()
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
    print(f"  ✓ uploaded new paywall (id {sid[:12]}…)")


if __name__ == "__main__":
    main()
