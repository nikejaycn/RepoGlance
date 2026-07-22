#!/bin/zsh
set -euo pipefail

: "${DEVSEARCH_TEAM_ID:?Set DEVSEARCH_TEAM_ID to the Apple Developer Team ID}"
: "${DEVSEARCH_NOTARY_PROFILE:?Set DEVSEARCH_NOTARY_PROFILE to an xcrun notarytool keychain profile}"

command -v xcodegen >/dev/null || {
  echo "xcodegen is required" >&2
  exit 1
}

signing_identities="$(security find-identity -v -p codesigning)"
[[ "${signing_identities}" == *"Developer ID Application"* ]] || {
  echo "No valid Developer ID Application identity was found in the keychain" >&2
  exit 1
}

security find-generic-password \
  -s com.apple.gke.notary.tool \
  -a "${DEVSEARCH_NOTARY_PROFILE}" >/dev/null 2>&1 || {
  echo "Notary profile '${DEVSEARCH_NOTARY_PROFILE}' was not found in the keychain" >&2
  exit 1
}

release_stamp="$(date +%Y%m%d-%H%M%S)"
release_root="${PWD}/.build/release-${release_stamp}"
archive_path="${release_root}/DevSearch.xcarchive"
app_path="${archive_path}/Products/Applications/DevSearch.app"
zip_path="${release_root}/DevSearch.zip"

mkdir -p "${release_root}"

xcodegen generate
xcodebuild archive \
  -project DevSearch.xcodeproj \
  -scheme DevSearch \
  -configuration Release \
  -archivePath "${archive_path}" \
  DEVELOPMENT_TEAM="${DEVSEARCH_TEAM_ID}" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_STYLE=Automatic

codesign --verify --deep --strict --verbose=2 "${app_path}"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${zip_path}"
xcrun notarytool submit "${zip_path}" \
  --keychain-profile "${DEVSEARCH_NOTARY_PROFILE}" \
  --wait
xcrun stapler staple "${app_path}"
xcrun stapler validate "${app_path}"

# Recreate the distributable after stapling the notarization ticket.
stapled_zip_path="${release_root}/DevSearch-notarized.zip"
ditto -c -k --sequesterRsrc --keepParent "${app_path}" "${stapled_zip_path}"
spctl --assess --type execute --verbose=2 "${app_path}"
sha256_path="${stapled_zip_path}.sha256"
shasum -a 256 "${stapled_zip_path}" > "${sha256_path}"

echo "Notarized build: ${stapled_zip_path}"
echo "SHA-256: ${sha256_path}"
