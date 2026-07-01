#!/usr/bin/env bash
set -euo pipefail

REPO="yorukot/superfile"
TEMPLATE="srcpkgs/superfile/template"

CURRENT_VERSION=$(grep -m1 '^version=' "$TEMPLATE" | cut -d= -f2)

LATEST_TAG=$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name // empty')

if [ -z "$LATEST_TAG" ]; then
  echo "Failed to fetch latest release for ${REPO}"
  exit 0
fi

LATEST_VERSION="${LATEST_TAG#v}"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
  echo "superfile is up to date (${CURRENT_VERSION})"
  exit 0
fi

echo "Updating superfile: ${CURRENT_VERSION} -> ${LATEST_VERSION}"

TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${LATEST_TAG}.tar.gz"
TMPFILE=$(mktemp)
curl -fsSL -o "$TMPFILE" "$TARBALL_URL"
NEW_CHECKSUM=$(sha256sum "$TMPFILE" | awk '{print $1}')
rm -f "$TMPFILE"

sed -i "s/^version=.*/version=${LATEST_VERSION}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${NEW_CHECKSUM}/" "$TEMPLATE"

echo "NEW_VERSION=${LATEST_VERSION}" >> "$GITHUB_ENV"
