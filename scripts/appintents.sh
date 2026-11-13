#!/usr/bin/env bash
# Generates Metadata.appintents (the description of App Intents actions: Shortcuts, widget buttons,
# configurable widgets, Control Center controls) and copies it into the built app and its extensions.
# On macOS Xcode does this; xtool on Linux does not, so without this step those actions don't work.
#
# Usage:  scripts/appintents.sh     (after `xtool dev build`, before `xtool install`)
#
# Uses appintentsmetadataprocessor, an open-source reimplementation of Apple's tool
# (https://codeberg.org/viraptor/re-appintentsmetadataprocessor). A Linux x86_64 build is
# included in tools/; set APPINTENTS_PROCESSOR to use another binary.
# Modules that declare no actions are skipped.

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle="${DARWIN_SDK_BUNDLE:-$HOME/.swiftpm/swift-sdks/darwin.artifactbundle}"

find_processor() {
    if [ -n "${APPINTENTS_PROCESSOR:-}" ]; then
        echo "$APPINTENTS_PROCESSOR"
    elif [ "$(uname -s)-$(uname -m)" = "Linux-x86_64" ]; then
        echo "$dir/tools/appintentsmetadataprocessor/linux-x86_64/appintentsmetadataprocessor"
    else
        command -v appintentsmetadataprocessor || true
    fi
}
processor="$(find_processor)"

product="$(awk '/^product:/ {print $2}' "$dir/xtool.yml")"
bundle_id="$(awk '/^bundleID:/ {print $2}' "$dir/xtool.yml")"
app="$dir/xtool/$product.app"
intermediates="$dir/.build/out/Intermediates.noindex/$product.build/Debug-iphoneos"

[ -d "$app" ] || { echo "appintents: $app not found, build first with 'xtool dev build'." >&2; exit 1; }
[ -d "$bundle" ] || { echo "appintents: iOS SDK not found in $bundle, run 'xtool setup' first." >&2; exit 1; }

sdk="$(ls -d "$bundle"/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS[0-9]*.sdk | sort -V | tail -1)"
xcode_build="$(grep -A1 ProductBuildVersion "$bundle/Xcode.app/Contents/version.plist" | sed -n 's:.*<string>\(.*\)</string>.*:\1:p')"
deployment="$(sed -n 's/.*\.iOS(\.v\([0-9]*\)).*/\1.0/p' "$dir/Package.swift" | head -1)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Generates Metadata.appintents for one module and copies it into its bundle (the app or an extension in PlugIns/).
# Usage: generate <module> <bundle ID> <destination bundle>
generate() {
    local module="$1" module_bundle_id="$2" dest="$3"
    local objects="$intermediates/$module-t.build/Objects-normal/arm64"
    local out="$work/$module"

    [ -d "$dest" ] || { echo "appintents: $dest not found." >&2; return 1; }
    # No actions in this module: nothing to generate.
    if ! grep -qs '"AppIntents.AppIntent"' "$objects"/*.swiftconstvalues; then
        rm -rf "$dest/Metadata.appintents"
        return 0
    fi
    [ -n "$processor" ] && [ -x "$processor" ] || {
        echo "appintents: appintentsmetadataprocessor not found. Build it from" >&2
        echo "  https://codeberg.org/viraptor/re-appintentsmetadataprocessor (cargo build --release)" >&2
        echo "and set APPINTENTS_PROCESSOR to the binary." >&2
        return 1
    }

    mkdir -p "$out"
    ls "$objects"/*.swiftconstvalues > "$out/constvalues.txt"
    ls "$dir"/Sources/"$module"/*.swift > "$out/sources.txt"

    "$processor" --output "$out/result" \
        --toolchain-dir "$bundle/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain" \
        --module-name "$module" --sdk-root "$sdk" --xcode-version "${xcode_build:-17F113}" \
        --platform-family iOS --deployment-target "${deployment:-17.0}" \
        --target-triple "arm64-apple-ios${deployment:-17.0}" --bundle-identifier "$module_bundle_id" \
        --source-file-list "$out/sources.txt" --swift-const-vals-list "$out/constvalues.txt" \
        --compile-time-extraction --force --quiet-warnings >"$out/log" 2>&1 \
        || { cat "$out/log" >&2; return 1; }

    rm -rf "$dest/Metadata.appintents"
    cp -r "$out/result/Metadata.appintents" "$dest/"
    local actions
    actions="$(python3 -I -c 'import json,sys; print(", ".join(json.load(open(sys.argv[1])).get("actions", {})))' "$dest/Metadata.appintents/extract.actionsdata" 2>/dev/null || true)"
    echo "App Intents actions in $module: ${actions:-none}"
}

generate "$product" "$bundle_id" "$app"

# Extensions (widget): "product bundleID" pairs from the extensions section of xtool.yml.
awk '/^extensions:/ {in_ext=1; next} /^[^ -]/ {in_ext=0}
     in_ext && /product:/ {p=$NF} in_ext && /bundleID:/ {print p, $NF}' "$dir/xtool.yml" |
while read -r ext ext_bundle_id; do
    generate "$ext" "$ext_bundle_id" "$app/PlugIns/$ext.appex"
done
