#!/bin/bash
set -e

REPO="solocco/iosevka-nf"
TEMPLATE="srcpkgs/iosevka-ori/template"

LATEST_VER=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
  jq -r '.tag_name // empty' | sed 's/^v//')

if [ -z "$LATEST_VER" ]; then
  LATEST_VER=$(curl -s "https://api.github.com/repos/$REPO/tags" | \
    jq -r '.[0].name // empty' | sed 's/^v//')
fi

CURRENT_VER=$(grep '^version=' "$TEMPLATE" | cut -d= -f2 | tr -d '"')

echo "Current version: $CURRENT_VER"
echo "Latest version: $LATEST_VER"

if [ -z "$LATEST_VER" ]; then
  echo "❌ Could not determine latest version, skipping"
  exit 0
fi

if [ "$LATEST_VER" = "$CURRENT_VER" ]; then
  echo "No update needed"
  exit 0
fi

echo "Update available: $CURRENT_VER -> $LATEST_VER"

URL="https://github.com/$REPO/releases/download/v${LATEST_VER}/Iosevka-TTF-${LATEST_VER}.tar.xz"
echo "Downloading from $URL..."
wget -q "$URL" -O /tmp/iosevka-ori-new.tar.xz

NEW_CHECKSUM=$(sha256sum /tmp/iosevka-ori-new.tar.xz | cut -d' ' -f1)
rm /tmp/iosevka-ori-new.tar.xz

sed -i "s/^version=.*/version=$LATEST_VER/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=\"$NEW_CHECKSUM\"/" "$TEMPLATE"

echo "Template updated to version $LATEST_VER"
echo "NEW_VERSION=$LATEST_VER" >> $GITHUB_ENV
