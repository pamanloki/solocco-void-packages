#!/bin/bash
set -e
REPO="solocco/PieMono"
TEMPLATE="srcpkgs/piemono-bin/template"

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

BASE="https://github.com/$REPO/releases/download/v${LATEST_VER}"

wget -q "$BASE/PieMono-TTF.tar.xz"      -O /tmp/ttf.tar.xz
wget -q "$BASE/PieMono-NerdFont.tar.xz" -O /tmp/nerd.tar.xz

CS1=$(sha256sum /tmp/ttf.tar.xz  | cut -d' ' -f1)
CS2=$(sha256sum /tmp/nerd.tar.xz | cut -d' ' -f1)

rm /tmp/ttf.tar.xz /tmp/nerd.tar.xz

sed -i "s/^version=.*/version=$LATEST_VER/" "$TEMPLATE"

python3 - "$TEMPLATE" "$CS1" "$CS2" <<'EOF'
import sys, re
path, cs1, cs2 = sys.argv[1:]
with open(path) as f:
    content = f.read()
new_checksum = f'checksum="{cs1}\n {cs2}"'
content = re.sub(r'checksum="[^"]*"', new_checksum, content, flags=re.DOTALL)
with open(path, 'w') as f:
    f.write(content)
EOF

echo "Template updated ke $LATEST_VER"
echo "NEW_VERSION=$LATEST_VER" >> $GITHUB_ENV
