#!/usr/bin/env bash
set -euo pipefail

REPO="noctalia-dev/noctalia"
TEMPLATE="srcpkgs/noctalia/template"

CURRENT_VERSION=$(grep -m1 '^version=' "$TEMPLATE" | cut -d= -f2)

LATEST_TAG=$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name // empty')

if [ -z "$LATEST_TAG" ]; then
  echo "Failed to fetch latest release for ${REPO}"
  exit 0
fi

# e.g. "v5.0.0-beta1" -> raw "5.0.0-beta1" -> void version "5.0.0beta1"
RAW_VERSION="${LATEST_TAG#v}"
LATEST_VERSION=$(echo "$RAW_VERSION" | tr -d '-')

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
  echo "noctalia is up to date (${CURRENT_VERSION})"
  exit 0
fi

echo "Updating noctalia: ${CURRENT_VERSION} -> ${LATEST_VERSION} (tag ${LATEST_TAG})"

TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/${LATEST_TAG}.tar.gz"
TMPFILE=$(mktemp)
curl -fsSL -o "$TMPFILE" "$TARBALL_URL"
NEW_CHECKSUM=$(sha256sum "$TMPFILE" | awk '{print $1}')
rm -f "$TMPFILE"

sed -i "s/^version=.*/version=${LATEST_VERSION}/" "$TEMPLATE"
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"
sed -i "s/^_tag=.*/_tag=\"${LATEST_TAG}\"/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${NEW_CHECKSUM}/" "$TEMPLATE"

echo "NEW_VERSION=${LATEST_VERSION}" >> "$GITHUB_ENV"
