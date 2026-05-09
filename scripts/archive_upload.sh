#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "${PROJECT_ROOT}"

# Auto-bump build number — Apple rejects duplicate (version, build) pairs.
PBX="${XCODEPROJ}/project.pbxproj"
CUR=$(grep -m1 "CURRENT_PROJECT_VERSION = " "${PBX}" | sed 's/.*= \([0-9]*\).*/\1/')
NEW=$((CUR + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION = ${CUR};/CURRENT_PROJECT_VERSION = ${NEW};/g" "${PBX}"
echo "build ${CUR} → ${NEW}"

# Push the new build into project.yml so xcodegen regen doesn't reset it.
sed -i '' "s/CURRENT_PROJECT_VERSION: \"${CUR}\"/CURRENT_PROJECT_VERSION: \"${NEW}\"/" "${PROJECT_ROOT}/project.yml" 2>/dev/null || true

rm -rf "${ARCHIVE_PATH}" "${EXPORT_PATH}"

# Manual signing — provisioning profile + identity baked into project.yml.
xcodebuild -project "${XCODEPROJ}" -scheme "${SCHEME}" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH}" \
  archive 2>&1 | xcbeautify --quiet

cat > "${PROJECT_ROOT}/build/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>export</string>
    <key>teamID</key><string>${TEAM_ID}</string>
    <key>signingStyle</key><string>manual</string>
    <key>signingCertificate</key><string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID}</key><string>${BUNDLE_ID} AppStore</string>
    </dict>
    <key>uploadSymbols</key><true/>
    <key>compileBitcode</key><false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${PROJECT_ROOT}/build/ExportOptions.plist" \
  -exportPath "${EXPORT_PATH}" \
  -allowProvisioningUpdates \
  -authenticationKeyID "${ASC_KEY_ID}" \
  -authenticationKeyIssuerID "${ASC_ISSUER_ID}" \
  -authenticationKeyPath "${ASC_KEY_PATH}" 2>&1 | xcbeautify --quiet

IPA=$(find "${EXPORT_PATH}" -name "*.ipa" | head -1)
echo "IPA: $IPA"

xcrun altool --upload-app --type ios -f "$IPA" \
  --apiKey "${ASC_KEY_ID}" --apiIssuer "${ASC_ISSUER_ID}" 2>&1 | tee build/upload.log

if grep -q "ERROR ITMS-" build/upload.log; then
    echo "✗ upload failed"; exit 1
fi
echo "✔ uploaded build ${NEW}"
echo "→ now wait 5–15 min for Apple processing, then run scripts/asc_finalize.py"
