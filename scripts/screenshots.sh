#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "${PROJECT_ROOT}"

# Build host app + UI test bundle, then run UI tests on the 6.9" device.
# The UI tests already screenshot every screen via XCTAttachment, so we
# just extract those PNGs from the result bundle and rename them by step.
RESULT_BUNDLE="${PROJECT_ROOT}/build/screenshots.xcresult"
rm -rf "${RESULT_BUNDLE}"

xcodebuild -project "${XCODEPROJ}" -scheme "${SCHEME}" \
  -destination "platform=iOS Simulator,name=${SCREEN_67_DEVICE}" \
  -resultBundlePath "${RESULT_BUNDLE}" \
  -only-testing:SoloLockUITests \
  test 2>&1 | xcbeautify --quiet

mkdir -p "${SCREENSHOT_DIR}"
EXPORT_DIR="${PROJECT_ROOT}/build/screenshot-attachments"
rm -rf "${EXPORT_DIR}"
xcrun xcresulttool export attachments --path "${RESULT_BUNDLE}" --output-path "${EXPORT_DIR}" >/dev/null

# Pull our named attachments (01-onboarding, 02-picker, …) into the
# fastlane screenshot dir, ordered.
python3 <<EOF
import json, os, shutil
manifest = json.load(open("${EXPORT_DIR}/manifest.json"))
seen = {}
for entry in manifest:
    for a in entry.get("attachments", []):
        n = a.get("suggestedHumanReadableName", "")
        # Names like "05-lock_0_<uuid>.png" — keep the "05-lock" prefix.
        if not (n[:2].isdigit() and n[2] == "-"):
            continue
        prefix = n.split("_")[0]
        # Take only the first occurrence per prefix (duplicates from xctest retries).
        if prefix in seen:
            continue
        src = os.path.join("${EXPORT_DIR}", a["exportedFileName"])
        dst = os.path.join("${SCREENSHOT_DIR}", f"iPhone_67_{prefix}.png")
        shutil.copyfile(src, dst)
        seen[prefix] = dst
        print(f"  ✓ {dst}")
EOF
echo "✔ screenshots in ${SCREENSHOT_DIR}"
