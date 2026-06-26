#!/bin/bash
set -e
REPO="malbiruk/driftwm"
TEMPLATE="srcpkgs/driftwm/template"

LATEST_VER=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
  jq -r '.tag_name // empty' | sed 's/^v//')
if [ -z "$LATEST_VER" ]; then
  LATEST_VER=$(curl -s "https://api.github.com/repos/$REPO/tags" | \
    jq -r '.[0].name // empty' | sed 's/^v//')
fi

CURRENT_VER=$(grep '^version=' "$TEMPLATE" | cut -d= -f2 | tr -d '"')
echo "Current: $CURRENT_VER | Latest: $LATEST_VER"

if [ -z "$LATEST_VER" ]; then
  echo "❌ Tidak bisa dapat versi terbaru, skip"
  exit 0
fi
if [ "$LATEST_VER" = "$CURRENT_VER" ]; then
  echo "Sudah up to date"
  exit 0
fi
echo "Update: $CURRENT_VER -> $LATEST_VER"

wget -q "https://github.com/$REPO/archive/refs/tags/v${LATEST_VER}.tar.gz" -O /tmp/driftwm.tar.gz
NEW_CHECKSUM=$(sha256sum /tmp/driftwm.tar.gz | cut -d' ' -f1)
rm /tmp/driftwm.tar.gz

sed -i "s/^version=.*/version=$LATEST_VER/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=$NEW_CHECKSUM/" "$TEMPLATE"

echo "Template updated ke $LATEST_VER"
echo "NEW_VERSION=$LATEST_VER" >> $GITHUB_ENV
