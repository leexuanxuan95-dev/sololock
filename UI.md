# SOLO LOCK · UI Design

## Visual Identity
- **Palette:** Vault gray `#22272B` · Lock brass `#B59252` · Open green `#3F6B4A` · SOS red `#A8482F` · Cream `#F4F1EA`
- **Typography:** Söhne (UI) · GT Sectra (agreement) · IBM Plex Mono (countdown)
- **Core motif:** A heavy old metal lock — the kind you can't reason with
- **Tone:** Notarial, weighty, slightly dry-humorous

## Key Screens (SwiftUI)

### 1. Onboarding
- Black → lock + key animate apart
- Lines: `your phone is loud.` / `you can't lock yourself.` / `let's give the key to someone — anyone.`
- CTA: `pick your lockmaster`

### 2. Lockmaster Picker
- 4 cards:
  - **AI Judge** (free) — no early unlock
  - **Random Delay** ($) — wait 15min + write 50 words to early-unlock
  - **Charity Lock** ($) — break early = $X to charity you chose
  - **Friend** (legacy) — invite a friend to hold key
- Tap → modal explains mechanics

### 3. Set Session
- Time wheel: 15m / 30m / 1h / 4h / 8h / overnight
- Apps to block (Family Controls picker — Instagram / TikTok / Twitter / etc)
- Charity selector (if Charity Lock) — $1 to $25 per failed session
- One button: `hand it over`

### 4. The Lock
- Animation: lock falls + clicks shut
- Full-screen countdown (Plex Mono large)
- Phase chip below: `clean slate · 2h 14m left`

### 5. Locked Mode (running)
- If user opens blocked app: full-screen takeover
  - Big lock icon + remaining time
  - Quote rotating every 5 seconds (Cal Newport / Naval / James Clear)
  - Bottom: emergency unlock (long-press 5s + reason)

### 6. Live Activity / Lock Screen
- Compact: lock icon + remaining
- Long-press: full controls (water log? — no, just countdown + emergency unlock)

### 7. Emergency Unlock Flow
- Long-press 5s → "are you sure? this is logged"
- For Random Delay mode: 15-min wait + 50-word reason input
- For Charity Lock: confirm $ donation, then unlock
- For AI Judge: not possible — must wait

### 8. Session End
- Lock opens (animated)
- Single line: `you held the line. 4h.`
- Today's stats: time saved, apps avoided

### 9. History
- List of sessions: duration, lockmaster type, outcome
- No streak shaming
- Charity donations subtotal

### 10. Apple Watch
- Complication: current session countdown
- Force-touch: emergency unlock
- Haptic at session end

### 11. Pro Paywall
- Hero: lock + key animation
- Tiers: $4.99/mo · $24.99/yr · $59 lifetime
- Charity tier explained: "100% goes to charity, we take $0"

## Micro-interactions
- **Heavy haptic** on lock close — feels physical, not toy
- **Lock Screen wallpaper:** during session, lock screen gets a subtle "X hours remaining" overlay
- **Charity donation:** Stripe Connect → user-chosen 501c3 directly, transparent
- **Emergency reason text:** is logged but private, never shown again unless user opens history

## Anti-design
- ✗ No streak / "longest session" pride wall
- ✗ No social comparison
- ✗ No "your friends focused longer"
- ✗ No upsell of focus music / white noise (that's other apps)
- ✗ No mockery / shame for emergency unlocks

## App Store Screenshots (5)
1. Lock + tagline `set a goal. lock yourself in. no friend required.`
2. 4 lockmaster cards
3. Live Activity countdown on Lock Screen
4. Charity Lock confirmation modal
5. Apple Watch session end "you held the line"

## Family Controls
- Requires user to grant Screen Time authorization at setup
- Per-session app selection from FamilyActivityPicker
- iOS-native blocking — cannot be uninstall-bypassed within session
