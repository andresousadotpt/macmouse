#!/usr/bin/env bash
#
# Bumps CFBundleShortVersionString (semver) and CFBundleVersion (build number).
# Usage: ./packaging/bump-version.sh [patch|minor|major]   (default: patch)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT/packaging/Info.plist"
BUMP="${1:-patch}"

CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")

major=0
minor=0
patch=0
IFS='.' read -r major minor patch _ <<< "$CURRENT"

case "$BUMP" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    echo "usage: bump-version.sh [patch|minor|major]" >&2
    exit 1
    ;;
esac

NEW="${major}.${minor}.${patch}"

BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
BUILD=$((BUILD + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

echo "$NEW"
