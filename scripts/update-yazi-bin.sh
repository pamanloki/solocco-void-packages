#!/bin/sh
# Update checker for yazi-bin
# Cek rilis terbaru sxyazi/yazi, update version= dan checksum= di template
# kalau ada versi baru. Dipanggil dari update-check.yml (sequential job chain).

set -e

PKG="yazi-bin"
REPO="sxyazi/yazi"
TEMPLATE="srcpkgs/${PKG}/template"
ASSET="yazi-x86_64-unknown-linux-gnu.zip"

current_version=$(grep -m1 '^version=' "$TEMPLATE" | cut -d= -f2)

latest_tag=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | \
	grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')

if [ -z "$latest_tag" ]; then
	echo "gagal ambil tag terbaru dari GitHub API" >&2
	exit 1
fi

if [ "$latest_tag" = "$current_version" ]; then
	echo "${PKG}: udah versi terbaru (${current_version})"
	exit 0
fi

echo "${PKG}: update ${current_version} -> ${latest_tag}"

download_url="https://github.com/${REPO}/releases/download/v${latest_tag}/${ASSET}"
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL -o "$tmpfile" "$download_url"
new_checksum=$(sha256sum "$tmpfile" | cut -d' ' -f1)

sed -i "s/^version=.*/version=${latest_tag}/" "$TEMPLATE"
sed -i "s/^checksum=.*/checksum=${new_checksum}/" "$TEMPLATE"

# revision balik ke 1 tiap kali versi bump
sed -i "s/^revision=.*/revision=1/" "$TEMPLATE"

echo "${PKG}: template updated ke ${latest_tag} (checksum ${new_checksum})"
echo "NEW_VERSION=${latest_tag}" >> "$GITHUB_ENV"
