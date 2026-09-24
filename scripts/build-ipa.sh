#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
scheme="${SCHEME:-VivaDicta}"
configuration="${CONFIGURATION:-Release}"
workspace="${WORKSPACE:-$repo_root/VivaDicta.xcodeproj/project.xcworkspace}"
destination="${DESTINATION:-generic/platform=iOS}"
export_options="${EXPORT_OPTIONS_PLIST:-$repo_root/ExportOptions-Development.plist}"
artifact_stamp="${BUILD_STAMP:-$(date +%Y%m%d-%H%M%S)}"
archive_path="${ARCHIVE_PATH:-$repo_root/build/VivaDicta-$artifact_stamp.xcarchive}"
export_path="${EXPORT_PATH:-$repo_root/build/ipa-$artifact_stamp}"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild is required. Run this script on macOS with Xcode that supports the target iOS SDK." >&2
    exit 127
fi

if [[ ! -f "$workspace/contents.xcworkspacedata" ]]; then
    echo "Workspace not found: $workspace" >&2
    exit 2
fi

if [[ ! -f "$export_options" ]]; then
    echo "Export options plist not found: $export_options" >&2
    exit 2
fi

mkdir -p "$(dirname -- "$archive_path")" "$export_path"

provisioning_flags=()
if [[ "${ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
    provisioning_flags+=("-allowProvisioningUpdates")
fi

echo "Resolving Swift packages..."
xcodebuild -resolvePackageDependencies \
    -workspace "$workspace" \
    -scheme "$scheme"

echo "Archiving $scheme ($configuration)..."
xcodebuild archive \
    -workspace "$workspace" \
    -scheme "$scheme" \
    -configuration "$configuration" \
    -destination "$destination" \
    -archivePath "$archive_path" \
    "${provisioning_flags[@]}"

echo "Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportOptionsPlist "$export_options" \
    -exportPath "$export_path" \
    "${provisioning_flags[@]}"

echo "IPA output:"
find "$export_path" -maxdepth 1 -type f -name '*.ipa' -print
