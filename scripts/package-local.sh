#!/bin/zsh
set -euo pipefail

command -v xcodegen >/dev/null || {
  echo "xcodegen is required" >&2
  exit 1
}

script_directory="${0:A:h}"
repository_root="${script_directory:h}"
cd "${repository_root}"

package_stamp="$(date +%Y%m%d-%H%M%S)"
package_root="${PACKAGE_ROOT:-${repository_root}/.build/local-macos14-${package_stamp}}"
derived_data="${package_root}/DerivedData"
built_app="${derived_data}/Build/Products/Release/RepoGlance.app"
dmg_staging="${package_root}/dmg-root"

mkdir -p "${package_root}"

xcodegen generate
xcodebuild build \
  -project DevSearch.xcodeproj \
  -scheme DevSearch \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "${derived_data}" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64"

binary_path="${built_app}/Contents/MacOS/RepoGlance"
architectures="$(lipo -archs "${binary_path}")"
[[ "${architectures}" == *"arm64"* && "${architectures}" == *"x86_64"* ]] || {
  echo "Expected a universal arm64/x86_64 binary, got: ${architectures}" >&2
  exit 1
}

minimum_system_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "${built_app}/Contents/Info.plist")"
[[ "${minimum_system_version}" == "14.0" ]] || {
  echo "Expected LSMinimumSystemVersion 14.0, got: ${minimum_system_version}" >&2
  exit 1
}

app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${built_app}/Contents/Info.plist")"
bundle_display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "${built_app}/Contents/Info.plist")"
bundle_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "${built_app}/Contents/Info.plist")"
bundle_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${built_app}/Contents/Info.plist")"
[[ "${bundle_display_name}" == "RepoGlance" && "${bundle_name}" == "RepoGlance" && "${bundle_executable}" == "RepoGlance" ]] || {
  echo "Expected RepoGlance bundle naming, got display='${bundle_display_name}', name='${bundle_name}', executable='${bundle_executable}'" >&2
  exit 1
}
artifact_name="RepoGlance-v${app_version}-macOS-universal"
zip_path="${package_root}/${artifact_name}.zip"
dmg_path="${package_root}/${artifact_name}.dmg"

# Remove build-host provenance and quarantine metadata before signing. These
# attributes are not part of the app and can confuse older Gatekeeper versions.
xattr -cr "${built_app}"

# Sign the complete bundle ad hoc so macOS can validate its internal integrity.
# This does not replace Developer ID signing or notarization, but produces a
# better-defined local package than leaving only the Mach-O linker signature.
codesign \
  --force \
  --deep \
  --sign - \
  --timestamp=none \
  "${built_app}"
# codesign on newer macOS versions can add build-host provenance metadata.
# Strip it after signing; extended attributes are not part of the code seal.
xattr -cr "${built_app}"
codesign --verify --deep --strict --verbose=2 "${built_app}"

ditto -c -k --sequesterRsrc --keepParent "${built_app}" "${zip_path}"
sha256_path="${zip_path}.sha256"

mkdir -p "${dmg_staging}"
ditto "${built_app}" "${dmg_staging}/RepoGlance.app"
ditto "${repository_root}/packaging/安装说明.txt" "${dmg_staging}/安装说明.txt"
ln -s /Applications "${dmg_staging}/Applications"
hdiutil create \
  -volname "RepoGlance" \
  -srcfolder "${dmg_staging}" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "${dmg_path}"
dmg_sha256_path="${dmg_path}.sha256"
(
  cd "${package_root}"
  shasum -a 256 "${zip_path:t}" > "${sha256_path:t}"
  shasum -a 256 "${dmg_path:t}" > "${dmg_sha256_path:t}"
)

echo "Local build: ${zip_path}"
echo "SHA-256: ${sha256_path}"
echo "Local DMG: ${dmg_path}"
echo "DMG SHA-256: ${dmg_sha256_path}"
