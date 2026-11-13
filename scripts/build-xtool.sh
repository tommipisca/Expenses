#!/usr/bin/env bash
# Builds xtool with tools/xtool/app-groups-free-account.patch, which keeps the App Group entitlement
# on free Apple accounts (needed by the widgets). The result is an AppImage in the current directory.
#
# Usage:  scripts/build-xtool.sh [version]     (default: 1.21.0, the version used for this project)
#
# Requires git and Docker with the compose plugin: the build runs in xtool's own container.

set -euo pipefail

version="${1:-1.21.0}"
patch="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/xtool/app-groups-free-account.patch"
out="$PWD"
src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT

git clone --quiet --depth 1 --branch "$version" https://github.com/xtool-org/xtool.git "$src"
git -C "$src" apply "$patch"
(cd "$src" && docker compose run --build --rm -e XTOOL_VERSION="$version-appgroups" xtool Linux/build.sh)

appimage="$(ls "$src"/Linux/packages/*.AppImage 2>/dev/null | head -1)"
[ -n "$appimage" ] || { echo "AppImage not found in $src/Linux/packages" >&2; exit 1; }
cp "$appimage" "$out/xtool-$version-appgroups.AppImage"
chmod +x "$out/xtool-$version-appgroups.AppImage"
echo "Built $out/xtool-$version-appgroups.AppImage"
echo "Put it in your PATH as 'xtool', e.g.: ln -sf \"$out/xtool-$version-appgroups.AppImage\" ~/.local/bin/xtool"
