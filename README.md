# Solo Lock — iOS 17 SwiftUI app

Implementation of `CONCEPT.md` + `UI.md`. Lock yourself out of phone apps for a focus session, with a choice of "lockmaster" (AI judge / random delay / charity / friend).

## What's in here

```
SoloLock/
  App/              SoloLockApp · RootView · MainTabView
  Theme/            Palette · Typography · Components (LockGlyph, VaultCard, BrassButtonStyle…)
  Models/           Session · Lockmaster · SessionDuration · BlockedAppGroup · Charity · ChatMessage
  Engine/
    JudgeIntent.swift       — keyword-based intent classifier
    JudgeVocabulary.swift   — 14 slot vocabularies (10–24 entries each)
    JudgeTemplates.swift    — ~80 templates across 11 intents
    JudgeEngine.swift       — composer; xorshift64* PRNG; sentence chaining; anti-repeat memo
    SessionEngine.swift     — running session, countdown, judge transcript, emergency flow
    Blocker.swift           — abstraction over Family Controls (StubBlocker for simulator)
    HapticEngine.swift
  Persistence/      SessionStore (JSON file) · Preferences (UserDefaults)
  Subscription/     SubscriptionStore (StoreKit 2)
  Resources/        Info.plist · Assets.xcassets (vault / brass / openGreen / sosRed / cream) · SoloLock.storekit
  Views/
    Onboarding/         lock + key animation, three lines, "pick your lockmaster"
    LockmasterPicker/   four cards + explainer sheet
    SessionSetup/       duration grid · app group toggles · charity slider
    Lock/               LockView (countdown) · JudgeChatView (algorithmic chat)
    LockedTakeover/     simulated takeover, rotating quotes
    EmergencyUnlock/    judge-refusal · random-delay (15m + 50 words) · charity confirm
    SessionEnd/         "you held the line"
    History/            stats + per-session rows, no streaks
    Paywall/            $4.99/mo · $24.99/yr · $59 lifetime
    Settings/           Pro state · about · replay onboarding
SoloLockTests/      JudgeEngineTests · SessionTests
```

## How the AI Judge works (no LLM, no network)

The judge replies are produced by a multi-layer combinatorial generator:

1. **Intent classifier** — `JudgeClassifier` scans the user's text for keyword signals and tags one of 11 intents (`urgent`, `boredom`, `socialPressure`, `craving`, `anxiety`, `anger`, `negotiation`, `existential`, `quiet`, `greeting`, `fallback`).
2. **Templates per intent** — ~7–12 sentence patterns each, e.g. `"{open}. {deny} — {reason}."`
3. **Slot fills** — 14 vocabulary pools (`coldOpens`, `denials`, `reasons`, `subjects`, `subjectVerbs`, `closers`, `boredomReframes`, `anxietyLines`, …). Each slot has 10–24 entries.
4. **Sentence chaining** — 35% chance to chain a second template, 8% chance to add a closer.
5. **Seeded PRNG** — `xorshift64*` seeded by the session UUID hashed with the user's text. Same text in two different sessions produces different replies; same text in the same session is dampened by an anti-repeat memo (rolling 32-hash set).

### Combinatorial size

A single template like `"{open}. {deny} — {reason}."` has

  13 (openers) × 14 (denials) × 14 (reasons) ≈ **2,548** unique surface forms.

Across all templates per intent (~10) and all intents (11), the per-turn space is in the **10⁵–10⁶** range. With sentence chaining (two-template combos) it reaches **10¹⁰–10¹²**, comfortably past "billions of unique replies." The `testBillionScaleVariety` unit test samples 200 replies and asserts >120 distinct outputs.

### Why this feels human

- **Notarial tone** is consistent (`"the docket reads"`, `"duly noted"`, `"the bench acknowledges"`) so the judge has a voice.
- **Intent-aware** — anxious user gets steady, calm lines; bored user gets reframes; bargainer gets wry refusals; quiet user gets quiet acknowledgment.
- **Phase-aware** — `{progress}` slot inserts `"clean slate"` / `"midway"` / `"last stretch"` based on elapsed/remaining minutes.
- **Anti-repeat** — the engine tries up to 5 candidates and prefers one not already said this session.

## Run on simulator (iOS 17+)

You'll need [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (or open the generated `.xcodeproj` directly in Xcode 16+).

```bash
cd 13_SOLOLOCK
xcodegen generate
open SoloLock.xcodeproj
# Cmd-R to run on iPhone 15 Pro simulator
```

### What works on simulator

- Onboarding → picker → setup → lock countdown → judge chat → emergency unlock flows → session end → history.
- Algorithmic AI Judge chat (everything in `JudgeEngine`).
- Heavy / rigid / soft haptics (where simulator supports them).
- StoreKit configuration file `SoloLock.storekit` is wired to the test scheme — paywall purchase flow can be tested without a real iTunes account.

### What requires a real device + entitlement

- Actually shielding Instagram/TikTok/etc. requires `com.apple.developer.family-controls` entitlement and the user's Screen Time authorization. Replace `StubBlocker` with a `FamilyControlsBlocker` that wraps `ManagedSettingsStore` + `DeviceActivityCenter`.
- Live Activities + Lock Screen widget + Apple Watch complication are scoped for v1.1 (separate widget extension target).

To preview the takeover that *would* appear on a real device when a blocked app launches, tap **"preview block"** on the LockView — it opens `LockedTakeoverView` with the rotating quotes.

## Tests

```bash
xcodebuild test -scheme SoloLock -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- `JudgeEngineTests` — classifier mappings, non-empty replies, billion-scale variety, anti-repeat dampening.
- `SessionTests` — `heldSeconds`, progress monotonicity, store round-trip, stats aggregation.
- `EdgeCaseTests` — every duration value, every Lockmaster gating rule, progress clamping with zero-duration, store insert/replace/delete/sort, every intent's reply, anti-repeat reset, lowercase+punctuation tone, SubscriptionStore non-crash.
- `SoloLockUITests` — 5 end-to-end flows that drive every screen and screenshot each: onboarding, picker, explainer, setup, lock, judge chat, charity setup, history, settings, paywall.

## App Store deployment

Full runbook at [scripts/APP_STORE_DEPLOY_RUNBOOK.md](scripts/APP_STORE_DEPLOY_RUNBOOK.md). Quick path:

```bash
source scripts/env.sh                                 # set per-app + ASC API env

# 1. Create the app at https://appstoreconnect.apple.com → My Apps → "+ New App"
#    Bundle ID: com.atrium.sololock · Name: Solo Lock: Focus Without Apps
#    Then write the numeric App ID into scripts/env.sh APP_ID + the
#    PER_APP block at the top of asc_finalize.py / asc_create_iap.py /
#    asc_create_subscriptions.py.

# 2. Generate App Store screenshots from the UI tests.
bash scripts/screenshots.sh                           # outputs to fastlane/screenshots/en-US

# 3. Configure all three IAPs in ASC.
python3 scripts/asc_create_iap.py                     # lifetime $59 NON_CONSUMABLE
python3 scripts/asc_create_subscriptions.py --all-territories
                                                      # monthly $4.99 + yearly $24.99
                                                      # (--all-territories is required
                                                      # for subs to reach READY_TO_SUBMIT)

# 4. Build, archive, upload.
bash scripts/archive_upload.sh                        # then wait 5–15 min for Apple processing

# 5. Push metadata, then submit.
python3 scripts/asc_finalize.py                       # push only — eyeball ASC web UI
python3 scripts/asc_finalize.py --submit              # submit version + IAP + sub group
```

Reviewer contact: Zhang Jiahao · jasperabundant@gmail.com · +60 17 702 3664.

## Anti-features (per CONCEPT.md)

- ✗ no streak shaming
- ✗ no "your friends focused longer" social
- ✗ no upsell of focus music / white noise
- ✗ no subscription gate on history
- ✗ no mockery for emergency unlocks
