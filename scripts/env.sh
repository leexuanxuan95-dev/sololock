#!/usr/bin/env bash
# Per-app environment for Solo Lock · iOS
# Source this before any other script in scripts/.

# === Apple Developer + ASC API (shared across all apps) ===
export TEAM_ID="96334T7L5L"
export ASC_KEY_ID="T496HJC8M8"
export ASC_ISSUER_ID="fb385764-17b2-458d-9e8c-0f10c9e185f4"
export ASC_KEY_PATH="/Users/augis/Downloads/AuthKey_T496HJC8M8.p8"

# === Per-app ===
export APP_NAME="Solo Lock: Focus Without Apps"
export APP_SKU="solo-lock-ios-001"
export BUNDLE_ID="com.atrium.sololock"
export APP_ID="6767774134"

export PROJECT_ROOT="/Users/augis/Desktop/toos/13_SOLOLOCK"
export SCHEME="SoloLock"
export XCODEPROJ="${PROJECT_ROOT}/${SCHEME}.xcodeproj"
export ARCHIVE_PATH="${PROJECT_ROOT}/build/${SCHEME}.xcarchive"
export EXPORT_PATH="${PROJECT_ROOT}/build/export"
export IPA_PATH="${EXPORT_PATH}/${SCHEME}.ipa"

# Screenshot devices (6.9" required for the 5+ App Store screenshots).
export SCREEN_67_DEVICE="iPhone 17 Pro Max"
export SCREEN_61_DEVICE="iPhone 17 Pro"
export SCREENSHOT_DIR="${PROJECT_ROOT}/fastlane/screenshots/en-US"

# Mirror .p8 to where altool/Spaceship expect it (idempotent)
mkdir -p "${HOME}/.appstoreconnect/private_keys"
cp -n "${ASC_KEY_PATH}" "${HOME}/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" 2>/dev/null || true
