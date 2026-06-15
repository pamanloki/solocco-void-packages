#!/bin/bash
set -e

REPO="solocco/iosevka-nf"
TEMPLATE="srcpkgs/iosevka-nf/template"

LATEST_VER=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
  jq -r '.tag_name' | sed 's/^v//')

CURRENT_VER=$(grep '^version=' "$TEMPLATE" | cut -d= -f2 | tr -d '"')

echo "Current version: $CURRENT_VER"
echo "Latest version: $LATEST_VER"

if [ "$LATEST_VER" = "$CURRENT_VER" ] || [ -z "$LATEST_VER" ]; then
  echo "No update needed"
  exit 0
fi

echo "Update available: $CURRENT_VER -> $LATEST_VER"

URL="https://github.com/$REPO/releases/download/v${LATEST_VER}/IosevkaNerd-TTF-${LATEST_VER}.tar.xz"
echo "Downloading from $URL..."
wget -q "$URL" -O /tmp/iosevka-nf-new.tar.xz

NEW_CHECKSUM=$(sha256sum /tmp/iosevka-nf-new.tar.xz | cut -d' ' -f1)
rm /tmp/iosevka-nf-new.tar.xz

sed -i "s/^version=.*/version=$LATEST_VER/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=\"$NEW_CHECKSUM\"/" "$TEMPLATE"

echo "Template updated to version $LATEST_VER"
echo "NEW_VERSION=$LATEST_VER" >> $GITHUB_ENV
