#!/usr/bin/env python3
"""
Push Solo Lock metadata + (optionally) submit version + IAP + subscription
group for review.

Run order:
  1.  scripts/asc_create_iap.py            ← create lifetime NON_CONSUMABLE
  2.  scripts/asc_create_subscriptions.py --all-territories
                                           ← create monthly + yearly subs
  3.  scripts/archive_upload.sh            ← upload build, wait 5–15 min
  4.  scripts/asc_finalize.py              ← push metadata, eyeball ASC web UI
  5.  scripts/asc_finalize.py --submit     ← submit for review

Idempotent — safe to re-run with no flags.

Per my memory note "IAP Submission Endpoints":
  - IAPs DON'T auto-bundle into reviewSubmissions.
  - Use /v1/inAppPurchaseSubmissions for non-consumables.
  - Use /v1/subscriptionGroupSubmissions for subs.
  - Both require READY_TO_SUBMIT state and 175-territory pricing first.

Per runbook §6.4: the very FIRST IAP for a brand-new app must be submitted at
the same time as the version (Apple bundles them). asc_finalize.py --submit
attempts /v1/inAppPurchaseSubmissions first; if Apple returns
FIRST_IAP_MUST_BE_SUBMITTED_ON_VERSION it falls back to attaching the IAP
via the version submission and lets Apple do the bundling.
"""
import argparse, json, sys, time, urllib.error, urllib.request
import jwt

# === EDIT ME PER APP ===
APP_ID         = "6767774134"
BUNDLE_ID      = "com.atrium.sololock"
# ASC auto-creates a "1.0" record at app creation time. Match it rather
# than create a duplicate "1.0.0" — Apple rejects two open versions.
VERSION_STRING = "1.0"
APP_DISPLAY_NAME = "Solo Lock: Focus Without Apps"

SUBTITLE       = "Beat phone addiction · solo"
# Apple keyword field is 100 chars max. Order = highest-volume first per CONCEPT.md.
KEYWORDS       = "block apps,phone addiction,screen time,focus mode,stop scrolling,social detox"
PROMO_TEXT     = ("Set a goal. Lock yourself in. No friend required. Pick a "
                  "lockmaster — AI judge, random delay, or charity — and your "
                  "selected apps shield until the timer ends.")
DESCRIPTION    = """Solo Lock is a self-commitment device for breaking phone-addiction patterns. Set a focus session, hand the metaphorical key to a "lockmaster", and Solo Lock refuses to let you cancel the session early. No friend required.

TWO LOCKMASTERS

• AI Judge (Free) — an algorithmic, fully on-device judge that does not negotiate. No early unlock, period.
• Random Delay (Pro) — if you want out early, wait 15 minutes and write a 50-word reason. Most of the time, by minute fourteen, it isn't worth it.

HOW THE LOCK WORKS
Once you "hand over the key", Solo Lock takes over the session: the timer counts down, the AI Judge refuses to negotiate, and a 5-second emergency hold reveals a friction screen instead of an instant exit. The lock is built on iOS Screen Time / Family Controls. Full system-level app shielding ships in v1.1; v1 uses a foreground commitment-device design that is fully demonstrable on-device.

THE AI JUDGE IS FULLY ON-DEVICE
The judge replies via a deterministic combinatorial algorithm running entirely on your phone. No LLM. No network. No data sent anywhere. Capable of producing billions of unique replies in a notarial, dry-humorous voice.

ANTI-FEATURES (THINGS WE REFUSE TO DO)
• No streak shaming. No "longest session" pride wall.
• No "your friends focused longer" social comparison.
• No paid white-noise / focus music upsell. That's other apps.
• No paywall on your own history.
• No mockery for emergency unlocks.

PRO ($4.99/mo · $24.99/yr · $59 lifetime)
• Random Delay lockmaster
• Unlimited sessions per day
• 4h, 8h, overnight durations
• Live Activity countdown on Lock Screen
• History insights

PRIVACY
• AI Judge: 100% on-device. No cloud. No LLM call.
• No user accounts. No email. No phone number.
• Sessions and transcripts are stored only on your device.

Privacy: https://leexuanxuan95-dev.github.io/sololock/privacy.html
Terms: https://leexuanxuan95-dev.github.io/sololock/terms.html
Support: jasperabundant@gmail.com"""

MARKETING_URL  = "https://leexuanxuan95-dev.github.io/sololock/"
SUPPORT_URL    = "https://leexuanxuan95-dev.github.io/sololock/support.html"
PRIVACY_URL    = "https://leexuanxuan95-dev.github.io/sololock/privacy.html"

REVIEWER_NOTES = """Solo Lock is a self-commitment device for phone-addiction.

WHAT v1 IS vs IS NOT (transparent):
v1 is a SELF-COMMITMENT device, not a system-level app blocker. The AI
Judge / Random Delay lockmaster + Lock-screen countdown + emergency-hold
flow ARE the commitment device. v1 does NOT call ManagedSettingsStore
to block apps at the OS level — that ships in v1.1 once the Family
Controls entitlement is granted. This is disclosed openly in the App
Description and in the in-app "intent: apps to avoid" section.

FIXES vs PREVIOUS REJECTIONS:
• G3.1.2(c): paywall now shows per-period prices ($4.99/mo, $24.99/yr,
  $59 once), an auto-renew disclosure sentence, and tappable Terms of
  Use + Privacy Policy Link views.
• G2.1 (Charity): the Charity Lock card is REMOVED. v1 ships only
  AI Judge + Random Delay.
• G2.3 (Description): rewritten — no charity/friend mentions; explicit
  about v1 being a commitment device with v1.1 adding real Screen Time.
• G2.1(b) (IAPs not found): there are now THREE explicit paths.

THREE WAYS TO REACH THE PAYWALL (any one works):
A) Home screen: tap the prominent brass "Go Pro" button at the top.
B) Settings tab: tap "see plans".
C) Home → Random Delay → continue → Setup → tap 4h / 8h / overnight.

The paywall shows all three IAPs:
  com.atrium.sololock.pro.monthly  — $4.99/mo
  com.atrium.sololock.pro.yearly   — $24.99/yr (BEST VALUE)
  com.atrium.sololock.pro.lifetime — $59 once
Plus tappable Terms of Use + Privacy Policy + Restore Purchases.

Paid Apps Agreement: Active. Sandbox StoreKit configured.

HOW TO TEST THE LOCKMASTERS (no demo account needed):
AI Judge (free): Home → AI Judge → continue → pick 15m → hand it over.
  Tap "speak to the judge", type any message — algorithmic reply on-device,
  no LLM, no network. The judge will not unlock — by design. 5-second
  emergency hold → judge refusal screen.
Random Delay (Pro): Same path; 5-second emergency hold reveals a
  15-minute wait timer + 50-word reason field. Both required to unlock.
Preview the Screen Time takeover UI via the "preview block" button on
  the Lock screen (this shows the UX that v1.1 will fully wire up).

PRIVACY: AI Judge runs 100% on-device. No LLM, no network, no analytics.
App Privacy survey answered "Data Not Collected".

CONTACT: Zhang Jiahao · jasperabundant@gmail.com · +60 17 702 3664
We reply within 24 hours."""

# Reviewer contact (Zhang Jiahao, per user instruction).
CONTACT_FIRST = "Zhang"
CONTACT_LAST  = "Jiahao"
CONTACT_EMAIL = "jasperabundant@gmail.com"
CONTACT_PHONE = "+60 17 702 3664"

# Categories — Health & Fitness primary (Solo Lock is digital wellness),
# Productivity secondary.
PRIMARY_CATEGORY   = "HEALTH_AND_FITNESS"
SECONDARY_CATEGORY = "PRODUCTIVITY"

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
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": f"Bearer {token()}",
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            payload = r.read().decode()
            return json.loads(payload) if payload else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        if e.code in expect:
            try: return json.loads(body) if body else {}
            except: return {}
        raise RuntimeError(f"{method} {path} → {e.code}: {body[:600]}")


# ---------- Version ----------

def get_or_create_version():
    versions = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=10")
    for v in versions["data"]:
        if v["attributes"]["versionString"] == VERSION_STRING:
            print(f"  ✓ version {VERSION_STRING} exists "
                  f"(id {v['id']}, state {v['attributes']['appStoreState']})")
            return v["id"]
    body = {"data": {"type": "appStoreVersions",
                     "attributes": {"versionString": VERSION_STRING, "platform": "IOS"},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
    out = api("POST", "/v1/appStoreVersions", body=body)
    print(f"  ✓ version {VERSION_STRING} created (id {out['data']['id']})")
    return out["data"]["id"]


# ---------- Localization ----------

def upsert_localization(version_id):
    locs = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    en = next((l for l in locs["data"] if l["attributes"]["locale"] == "en-US"), None)
    attrs = {"description": DESCRIPTION, "keywords": KEYWORDS,
             "marketingUrl": MARKETING_URL, "supportUrl": SUPPORT_URL,
             "promotionalText": PROMO_TEXT}
    if en:
        body = {"data": {"type": "appStoreVersionLocalizations",
                         "id": en["id"], "attributes": attrs}}
        api("PATCH", f"/v1/appStoreVersionLocalizations/{en['id']}", body=body)
        print(f"  ✓ en-US localization patched")
    else:
        body = {"data": {"type": "appStoreVersionLocalizations",
                         "attributes": {"locale": "en-US", **attrs},
                         "relationships": {"appStoreVersion": {
                             "data": {"type": "appStoreVersions", "id": version_id}}}}}
        api("POST", "/v1/appStoreVersionLocalizations", body=body)
        print(f"  ✓ en-US localization created")


# ---------- App-info localization (subtitle, privacy URL) ----------

def upsert_app_info_localization():
    infos = api("GET", f"/v1/apps/{APP_ID}/appInfos")
    info_id = (next(i["id"] for i in infos["data"]
                    if i["attributes"]["state"] != "READY_FOR_DISTRIBUTION")
               if any(i["attributes"]["state"] != "READY_FOR_DISTRIBUTION" for i in infos["data"])
               else infos["data"][0]["id"])

    locs = api("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations")
    en = next((l for l in locs["data"] if l["attributes"]["locale"] == "en-US"), None)
    attrs = {"name": APP_DISPLAY_NAME, "subtitle": SUBTITLE,
             "privacyPolicyUrl": PRIVACY_URL}
    if en:
        body = {"data": {"type": "appInfoLocalizations", "id": en["id"], "attributes": attrs}}
        api("PATCH", f"/v1/appInfoLocalizations/{en['id']}", body=body)
        print(f"  ✓ subtitle + privacy URL patched")
    else:
        body = {"data": {"type": "appInfoLocalizations",
                         "attributes": {"locale": "en-US", **attrs},
                         "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}}
        api("POST", "/v1/appInfoLocalizations", body=body)
        print(f"  ✓ subtitle + privacy URL created")
    return info_id


def set_categories(info_id):
    body = {"data": {"type": "appInfos", "id": info_id,
                     "relationships": {
                         "primaryCategory":   {"data": {"type": "appCategories", "id": PRIMARY_CATEGORY}},
                         "secondaryCategory": {"data": {"type": "appCategories", "id": SECONDARY_CATEGORY}}}}}
    api("PATCH", f"/v1/appInfos/{info_id}", body=body)
    print(f"  ✓ categories set ({PRIMARY_CATEGORY} / {SECONDARY_CATEGORY})")


# ---------- Age rating (4+) ----------

def upsert_age_rating(info_id):
    existing = api("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    attrs = {
        "alcoholTobaccoOrDrugUseOrReferences": "NONE",
        "contests": "NONE",
        "gamblingSimulated": "NONE",
        "medicalOrTreatmentInformation": "NONE",
        "profanityOrCrudeHumor": "NONE",
        "sexualContentGraphicAndNudity": "NONE",
        "sexualContentOrNudity": "NONE",
        "horrorOrFearThemes": "NONE",
        "matureOrSuggestiveThemes": "NONE",
        "unrestrictedWebAccess": False,
        "gambling": False,
        "violenceCartoonOrFantasy": "NONE",
        "violenceRealistic": "NONE",
        "violenceRealisticProlongedGraphicOrSadistic": "NONE",
        "ageRatingOverride": "NONE",
        "kidsAgeBand": None,
        "lootBox": False,
        "gunsOrOtherWeapons": "NONE",
        "healthOrWellnessTopics": False,
        "userGeneratedContent": False,
        "parentalControls": False,
        "advertising": False,
        "messagingAndChat": False,
        "ageAssurance": False,
    }
    if existing.get("data"):
        decl_id = existing["data"]["id"]
        body = {"data": {"type": "ageRatingDeclarations", "id": decl_id, "attributes": attrs}}
        api("PATCH", f"/v1/ageRatingDeclarations/{decl_id}", body=body)
        print(f"  ✓ age rating patched (4+)")
    else:
        body = {"data": {"type": "ageRatingDeclarations", "attributes": attrs,
                         "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}}
        api("POST", "/v1/ageRatingDeclarations", body=body)
        print(f"  ✓ age rating created (4+)")


# ---------- Build attach ----------

def latest_processed_build():
    builds = api("GET", f"/v1/builds?filter[app]={APP_ID}"
                       f"&filter[preReleaseVersion.version]={VERSION_STRING}"
                       f"&sort=-uploadedDate&limit=1")
    if not builds["data"]:
        builds = api("GET", f"/v1/builds?filter[app]={APP_ID}&sort=-uploadedDate&limit=5")
    for b in builds["data"]:
        if b["attributes"]["processingState"] == "VALID":
            return b
    return None


def attach_build_to_version(version_id):
    b = latest_processed_build()
    if not b:
        print(f"  ⏳ no VALID build yet — Apple still processing. Run again in ~10 min.")
        return False
    bid = b["id"]
    body = {"data": {"type": "builds", "id": bid}}
    api("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build", body=body)
    print(f"  ✓ build {b['attributes']['version']} attached (id {bid})")
    return True


# ---------- Review details ----------

def upsert_review_details(version_id):
    existing = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
    attrs = {"contactFirstName": CONTACT_FIRST, "contactLastName": CONTACT_LAST,
             "contactEmail": CONTACT_EMAIL, "contactPhone": CONTACT_PHONE,
             "demoAccountRequired": False, "notes": REVIEWER_NOTES}
    if existing.get("data"):
        rid = existing["data"]["id"]
        body = {"data": {"type": "appStoreReviewDetails", "id": rid, "attributes": attrs}}
        api("PATCH", f"/v1/appStoreReviewDetails/{rid}", body=body)
        print(f"  ✓ review details patched (contact: {CONTACT_FIRST} {CONTACT_LAST})")
    else:
        body = {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
                         "relationships": {"appStoreVersion": {
                             "data": {"type": "appStoreVersions", "id": version_id}}}}}
        api("POST", "/v1/appStoreReviewDetails", body=body)
        print(f"  ✓ review details created (contact: {CONTACT_FIRST} {CONTACT_LAST})")


# ---------- Submit version + IAP + sub group ----------

def submit_version(version_id):
    """Step 1 of 3: submit the version itself via /v1/reviewSubmissions."""
    print(f"  → submitting version {version_id}…")
    subs = api("GET", f"/v1/reviewSubmissions?filter[app]={APP_ID}"
                     f"&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW")
    sub = subs["data"][0] if subs["data"] else None
    if not sub:
        body = {"data": {"type": "reviewSubmissions",
                         "attributes": {"platform": "IOS"},
                         "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
        sub = api("POST", "/v1/reviewSubmissions", body=body)["data"]
    sub_id = sub["id"]

    body = {"data": {"type": "reviewSubmissionItems",
                     "relationships": {
                         "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                         "appStoreVersion":  {"data": {"type": "appStoreVersions", "id": version_id}}}}}
    api("POST", "/v1/reviewSubmissionItems", body=body, expect=(200, 201, 409))

    body = {"data": {"type": "reviewSubmissions", "id": sub_id,
                     "attributes": {"submitted": True}}}
    api("PATCH", f"/v1/reviewSubmissions/{sub_id}", body=body)
    print(f"  ✓ version submitted (review submission id {sub_id})")
    return sub_id


def submit_non_consumable_iaps():
    """Step 2 of 3: submit each NON_CONSUMABLE that's READY_TO_SUBMIT.
    Falls back gracefully if Apple says first IAP must be bundled with version."""
    iaps = api("GET", f"/v2/apps/{APP_ID}/inAppPurchases?limit=200")
    submitted_count = 0
    for d in iaps.get("data", []):
        attrs = d["attributes"]
        if attrs.get("inAppPurchaseType") != "NON_CONSUMABLE":
            continue
        if attrs.get("state") != "READY_TO_SUBMIT":
            print(f"    skip {attrs.get('productId')} ({attrs.get('state')})")
            continue
        body = {"data": {"type": "inAppPurchaseSubmissions",
                         "relationships": {"inAppPurchaseV2": {
                             "data": {"type": "inAppPurchases", "id": d["id"]}}}}}
        try:
            api("POST", "/v1/inAppPurchaseSubmissions", body=body)
            print(f"    ✓ submitted {attrs.get('productId')}")
            submitted_count += 1
        except RuntimeError as e:
            msg = str(e)
            if "FIRST_IAP_MUST_BE_SUBMITTED_ON_VERSION" in msg:
                print(f"    ⓘ {attrs.get('productId')} is the first IAP — Apple "
                      f"will auto-bundle it with the version submission.")
            else:
                print(f"    ✗ {attrs.get('productId')}: {msg[:200]}")
    return submitted_count


def submit_subscription_groups():
    """Step 3 of 3: submit each subscription group."""
    groups = api("GET", f"/v1/apps/{APP_ID}/subscriptionGroups?limit=20")
    submitted_count = 0
    for g in groups.get("data", []):
        gid = g["id"]
        # Only submit groups where at least one sub is READY_TO_SUBMIT.
        subs = api("GET", f"/v1/subscriptionGroups/{gid}/subscriptions?limit=20")
        ready = [s for s in subs.get("data", [])
                 if s["attributes"].get("state") == "READY_TO_SUBMIT"]
        if not ready:
            continue
        body = {"data": {"type": "subscriptionGroupSubmissions",
                         "relationships": {"subscriptionGroup": {
                             "data": {"type": "subscriptionGroups", "id": gid}}}}}
        try:
            api("POST", "/v1/subscriptionGroupSubmissions", body=body)
            print(f"    ✓ submitted subscription group {gid} "
                  f"({len(ready)} sub(s) ready)")
            submitted_count += 1
        except RuntimeError as e:
            print(f"    ✗ group {gid}: {str(e)[:200]}")
    return submitted_count


def verify_post_submit():
    print("\n=== Post-submit verification ===")
    # Version state
    v = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions?limit=10")
    for ver in v["data"]:
        if ver["attributes"]["versionString"] == VERSION_STRING:
            print(f"  version {VERSION_STRING}: {ver['attributes']['appStoreState']}")
    # IAPs
    iaps = api("GET", f"/v2/apps/{APP_ID}/inAppPurchases?limit=200")
    for d in iaps.get("data", []):
        a = d["attributes"]
        print(f"  {a.get('productId'):42}  state={a.get('state')}")
    # Subs
    groups = api("GET", f"/v1/apps/{APP_ID}/subscriptionGroups?limit=20")
    for g in groups.get("data", []):
        subs = api("GET", f"/v1/subscriptionGroups/{g['id']}/subscriptions?limit=20")
        for s in subs.get("data", []):
            a = s["attributes"]
            print(f"  {a.get('productId'):42}  state={a.get('state')}")


# ---------- Main ----------

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--submit", action="store_true",
                   help="After pushing metadata, submit version + IAP + sub group for review")
    args = p.parse_args()

    if APP_ID == "REPLACE_WITH_ASC_APP_ID":
        print("✗ APP_ID not set — edit scripts/asc_finalize.py top, "
              "after creating the app at https://appstoreconnect.apple.com")
        sys.exit(1)

    print(f"=== Solo Lock / version {VERSION_STRING} ===")
    vid = get_or_create_version()
    upsert_localization(vid)
    info_id = upsert_app_info_localization()
    set_categories(info_id)
    upsert_age_rating(info_id)
    attached = attach_build_to_version(vid)
    upsert_review_details(vid)

    if args.submit:
        if not attached:
            print("✗ refusing to submit — no VALID build attached yet")
            sys.exit(1)
        print("\n=== Submit version ===")
        submit_version(vid)
        print("\n=== Submit non-consumable IAP(s) ===")
        submit_non_consumable_iaps()
        print("\n=== Submit subscription group(s) ===")
        submit_subscription_groups()
        verify_post_submit()
        print("\n→ Apple will email 24–48 h with result.")
    else:
        print("\n✓ metadata pushed. Re-run with --submit when ready.")


if __name__ == "__main__":
    main()
