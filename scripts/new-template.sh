#!/bin/bash
# new-template.sh - scaffold a new xbps template + register it in packages.json.
#
# Bikin kerangka srcpkgs/<name>/template yang udah bener boilerplate-nya,
# lalu daftarin package-nya ke packages.json (biar auto-update & auto-build
# ikut jalan). Checksum sengaja diisi placeholder 64 nol -- build pertama
# bakal "SHA256 mismatch" dan job autofix di CI otomatis nulis checksum yang
# bener. Jadi kamu cukup isi bagian yang beneran package-specific: depends /
# makedepends (+ do_install kalau perlu).
#
# Contoh:
#   scripts/new-template.sh --name foo --strategy source-tarball \
#     --repo owner/foo --version 1.2.3 --build-style gnu-configure \
#     --desc "Foo does things" --license MIT --homepage https://foo.dev
#
#   scripts/new-template.sh --name foo-bin --strategy binary-asset \
#     --repo owner/foo --version 1.2.3 --asset "foo-{version}-x86_64.tar.gz"
#
#   scripts/new-template.sh --name Bar-icon-theme --strategy icon-theme \
#     --repo vinceliuice/Bar-icon-theme --tag 2026-09-10
#
#   scripts/new-template.sh --name baz-font --strategy font --font Baz --version 1.0
#
#   scripts/new-template.sh --name qux --strategy static --version 1.0
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# --- defaults ---
NAME=""; STRATEGY=""; VERSION=""; REPO=""; DESC=""; HOMEPAGE=""; LICENSE=""
BUILD="true"; RESTRICTED="false"; BUILD_STYLE=""; ASSET=""; FONT=""; TAG=""
FALLBACK_TAGS="false"; DASH_STRIP="false"; SET_TAG_VAR="false"
URL_V_PREFIX="false"; QUOTED_CHECKSUM="true"; MAINTAINER="solocco <noreply@github.com>"

[ $# -eq 0 ] && usage 0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --strategy) STRATEGY="$2"; shift 2;;
    --version) VERSION="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --desc) DESC="$2"; shift 2;;
    --homepage) HOMEPAGE="$2"; shift 2;;
    --license) LICENSE="$2"; shift 2;;
    --maintainer) MAINTAINER="$2"; shift 2;;
    --build) BUILD="$2"; shift 2;;
    --restricted) RESTRICTED="true"; shift;;
    --build-style) BUILD_STYLE="$2"; shift 2;;
    --asset) ASSET="$2"; shift 2;;
    --font) FONT="$2"; shift 2;;
    --tag) TAG="$2"; shift 2;;
    --fallback-tags) FALLBACK_TAGS="true"; shift;;
    --dash-strip) DASH_STRIP="true"; shift;;
    --set-tag-var) SET_TAG_VAR="true"; shift;;
    --url-v-prefix) URL_V_PREFIX="true"; shift;;
    --quoted-checksum) QUOTED_CHECKSUM="$2"; shift 2;;
    -h|--help) usage 0;;
    *) die "opsi gak dikenal: $1 (pakai --help)";;
  esac
done

# --- repo root (jalan dari mana aja) ---
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
[ -f packages.json ] || die "packages.json gak ketemu di $ROOT"
command -v jq >/dev/null || die "butuh jq"

# --- validasi dasar ---
[ -n "$NAME" ] || die "--name wajib"
[ -n "$STRATEGY" ] || die "--strategy wajib (source-tarball|binary-asset|icon-theme|font|static)"
echo "$NAME" | grep -qE '^[A-Za-z0-9._+-]+$' || die "nama package gak valid: $NAME"
[ -d "srcpkgs/$NAME" ] && die "srcpkgs/$NAME sudah ada"
jq -e --arg n "$NAME" '.packages[] | select(.package==$n)' packages.json >/dev/null 2>&1 \
  && die "$NAME sudah terdaftar di packages.json"

PLACEHOLDER="0000000000000000000000000000000000000000000000000000000000000000"
: "${DESC:=TODO: short description}"
: "${LICENSE:=TODO}"

emit_common_tail() {
  cat <<EOF

post_install() {
	: # TODO: vlicense LICENSE  (kalau upstream punya file lisensi)
}
EOF
}

case "$STRATEGY" in
  source-tarball)
    [ -n "$REPO" ] || die "source-tarball butuh --repo owner/name"
    [ -n "$VERSION" ] || die "source-tarball butuh --version"
    : "${HOMEPAGE:=https://github.com/$REPO}"
    bs_line=""; [ -n "$BUILD_STYLE" ] && bs_line="build_style=$BUILD_STYLE"
    mkdir -p "srcpkgs/$NAME"
    {
      echo "# Template file for '$NAME'"
      echo "pkgname=$NAME"
      echo "version=$VERSION"
      echo "revision=1"
      [ -n "$bs_line" ] && echo "$bs_line"
      echo "hostmakedepends=\"\"   # TODO"
      echo "makedepends=\"\"       # TODO"
      echo "depends=\"\"           # TODO"
      echo "short_desc=\"$DESC\""
      echo "maintainer=\"$MAINTAINER\""
      echo "license=\"$LICENSE\""
      echo "homepage=\"$HOMEPAGE\""
      echo "changelog=\"https://github.com/$REPO/releases\""
      echo "distfiles=\"https://github.com/$REPO/archive/refs/tags/\${version}.tar.gz\""
      echo "checksum=$PLACEHOLDER"
      emit_common_tail
    } > "srcpkgs/$NAME/template"
    pkg_json=$(jq -n --arg p "$NAME" --arg r "$REPO" \
      --argjson restr "$RESTRICTED" --argjson build "$BUILD" \
      --argjson ft "$FALLBACK_TAGS" --argjson ds "$DASH_STRIP" --argjson stv "$SET_TAG_VAR" \
      '{package:$p, restricted:$restr, build:$build, strategy:"source-tarball", repo:$r}
       + (if $ft then {fallback_tags:true} else {} end)
       + (if $ds then {dash_strip:true} else {} end)
       + (if $stv then {set_tag_var:true} else {} end)')
    ;;

  binary-asset)
    [ -n "$REPO" ] || die "binary-asset butuh --repo owner/name"
    [ -n "$VERSION" ] || die "binary-asset butuh --version"
    [ -n "$ASSET" ] || die "binary-asset butuh --asset (pakai {version} sbg placeholder)"
    : "${HOMEPAGE:=https://github.com/$REPO}"
    dlpath='${version}'; [ "$URL_V_PREFIX" = "true" ] && dlpath='v${version}'
    asset_resolved=${ASSET//\{version\}/\$\{version\}}
    if [ "$QUOTED_CHECKSUM" = "true" ]; then cksum_line="checksum=\"$PLACEHOLDER\""; else cksum_line="checksum=$PLACEHOLDER"; fi
    mkdir -p "srcpkgs/$NAME"
    {
      echo "# Template file for '$NAME'"
      echo "pkgname=$NAME"
      echo "version=$VERSION"
      echo "revision=1"
      echo "archs=\"x86_64\""
      echo "hostmakedepends=\"\"   # TODO (mis. tar, unzip)"
      echo "depends=\"\"           # TODO (shared libs yang dibutuhin binary)"
      echo "short_desc=\"$DESC\""
      echo "maintainer=\"$MAINTAINER\""
      echo "license=\"$LICENSE\""
      echo "homepage=\"$HOMEPAGE\""
      echo "distfiles=\"https://github.com/$REPO/releases/download/$dlpath/$asset_resolved\""
      echo "$cksum_line"
      echo ""
      echo "do_install() {"
      echo "	: # TODO: pasang file dari \$wrksrc ke \$DESTDIR (vbin/vcopy/vinstall)"
      echo "}"
    } > "srcpkgs/$NAME/template"
    pkg_json=$(jq -n --arg p "$NAME" --arg r "$REPO" --arg a "$ASSET" \
      --argjson restr "$RESTRICTED" --argjson build "$BUILD" \
      --argjson qc "$QUOTED_CHECKSUM" --argjson uvp "$URL_V_PREFIX" \
      '{package:$p, restricted:$restr, build:$build, strategy:"binary-asset", repo:$r, asset:$a, quoted_checksum:$qc, url_v_prefix:$uvp}')
    ;;

  icon-theme)
    [ -n "$REPO" ] || die "icon-theme butuh --repo owner/name"
    [ -n "$TAG" ] || die "icon-theme butuh --tag (mis. 2026-09-10)"
    VERSION=$(echo "$TAG" | tr -d '-')
    : "${HOMEPAGE:=https://github.com/$REPO}"
    : "${LICENSE:=GPL-3.0-only}"
    mkdir -p "srcpkgs/$NAME"
    {
      echo "# Template file for '$NAME'"
      echo "pkgname=$NAME"
      echo "version=$VERSION"
      echo "revision=1"
      echo "_tag=\"$TAG\""
      echo "hostmakedepends=\"gtk-update-icon-cache\""
      echo "depends=\"hicolor-icon-theme\""
      echo "short_desc=\"$DESC\""
      echo "maintainer=\"$MAINTAINER\""
      echo "license=\"$LICENSE\""
      echo "homepage=\"$HOMEPAGE\""
      echo "changelog=\"https://github.com/$REPO/tags\""
      echo "distfiles=\"https://github.com/$REPO/archive/refs/tags/\${_tag}.tar.gz\""
      echo "checksum=$PLACEHOLDER"
      echo ""
      echo "do_install() {"
      echo "	bash ./install.sh -d \"\${DESTDIR}/usr/share/icons\""
      echo "	find \"\${DESTDIR}/usr/share/icons\" -name 'icon-theme.cache' -delete"
      echo "}"
    } > "srcpkgs/$NAME/template"
    pkg_json=$(jq -n --arg p "$NAME" --arg r "$REPO" \
      --argjson restr "$RESTRICTED" --argjson build "$BUILD" \
      '{package:$p, restricted:$restr, build:$build, strategy:"source-tarball", repo:$r, fallback_tags:true, dash_strip:true, set_tag_var:true}')
    ;;

  font)
    [ -n "$FONT" ] || die "font butuh --font NamaFont"
    [ -n "$VERSION" ] || die "font butuh --version"
    : "${HOMEPAGE:=https://github.com/solocco/my-fonts}"
    : "${LICENSE:=OFL-1.1}"
    mkdir -p "srcpkgs/$NAME"
    {
      echo "# Template file for '$NAME'"
      echo "pkgname=$NAME"
      echo "version=$VERSION"
      echo "revision=1"
      echo "depends=\"font-util\""
      echo "short_desc=\"$DESC\""
      echo "maintainer=\"$MAINTAINER\""
      echo "license=\"$LICENSE\""
      echo "homepage=\"$HOMEPAGE\""
      echo "distfiles=\"https://github.com/solocco/my-fonts/releases/download/$FONT-v\${version}/$FONT-TTF.tar.xz"
      echo " https://github.com/solocco/my-fonts/releases/download/$FONT-v\${version}/$FONT-NerdFont.tar.xz\""
      echo "checksum=\"$PLACEHOLDER"
      echo " $PLACEHOLDER\""
      echo ""
      echo "font_dirs=\"/usr/share/fonts/TTF\""
      echo ""
      echo "do_install() {"
      echo "	vmkdir usr/share/fonts/TTF"
      echo "	vcopy \"*.ttf\" usr/share/fonts/TTF"
      echo "}"
    } > "srcpkgs/$NAME/template"
    pkg_json=$(jq -n --arg p "$NAME" --arg f "$FONT" \
      --argjson restr "$RESTRICTED" --argjson build "$BUILD" \
      '{package:$p, restricted:$restr, build:$build, strategy:"font", font:$f}')
    ;;

  static)
    [ -n "$VERSION" ] || die "static butuh --version"
    mkdir -p "srcpkgs/$NAME"
    {
      echo "# Template file for '$NAME'"
      echo "pkgname=$NAME"
      echo "version=$VERSION"
      echo "revision=1"
      echo "short_desc=\"$DESC\""
      echo "maintainer=\"$MAINTAINER\""
      echo "license=\"$LICENSE\""
      echo "homepage=\"${HOMEPAGE:-https://github.com/solocco/solocco-void-packages}\""
      echo "# static: gak ada version tracking otomatis; isi build/install manual."
      echo ""
      echo "do_install() {"
      echo "	: # TODO"
      echo "}"
    } > "srcpkgs/$NAME/template"
    pkg_json=$(jq -n --arg p "$NAME" \
      --argjson restr "$RESTRICTED" --argjson build "$BUILD" \
      '{package:$p, restricted:$restr, build:$build, strategy:"static"}')
    ;;

  *)
    die "strategy gak dikenal: $STRATEGY (source-tarball|binary-asset|icon-theme|font|static)"
    ;;
esac

# --- register di packages.json (append, format rapi) ---
tmp=$(mktemp)
jq --argjson entry "$pkg_json" '.packages += [$entry]' packages.json > "$tmp"
jq -e . "$tmp" >/dev/null || { rm -f "$tmp"; die "packages.json jadi invalid, batal"; }
mv "$tmp" packages.json

echo "OK. Dibuat:"
echo "  - srcpkgs/$NAME/template"
echo "  - entry packages.json"
echo ""
echo "Langkah berikutnya:"
echo "  1. Edit srcpkgs/$NAME/template -> isi bagian TODO (depends/makedepends/do_install)."
if [ "$STRATEGY" = "font" ]; then
  echo "  2. Font pakai 2 checksum -> autofix CI TIDAK ngisi ini otomatis."
  echo "     Jalanin: scripts/update.sh \"\$(jq -c '.packages[]|select(.package==\"$NAME\")' packages.json)\""
  echo "     buat ngisi version+checksum, atau biarin Update Check harian yang isi."
else
  echo "  2. Checksum = placeholder; commit + push -> build pertama gagal 'SHA256 mismatch'"
  echo "     -> job autofix CI otomatis nulis checksum yang bener + rebuild."
fi
echo "  3. git add srcpkgs/$NAME packages.json && git commit && push."
