#!/bin/sh
# generate-index.sh <output-dir> <srcpkgs-dir>
# Generates index.html for the xbps repo landing page.

set -e

OUT_DIR="${1:?Usage: $0 <output-dir> <srcpkgs-dir>}"
SRCPKGS_DIR="${2:?Usage: $0 <output-dir> <srcpkgs-dir>}"

REPO_URL="https://solocco-void-packages.pages.dev"
GITHUB_URL="https://github.com/solocco/solocco-void-packages"
SIGNEDBY="solocco"

# Build package list HTML
PKG_ITEMS=""
for tmpl in "$SRCPKGS_DIR"/*/template; do
    [ -f "$tmpl" ] || continue
    pkgdir="$(dirname "$tmpl")"
    pkgname="$(basename "$pkgdir")"

    # Skip subpackage symlinks
    [ -L "$pkgdir" ] && continue

    version="$(grep -E '^version=' "$tmpl" | head -1 | sed 's/^version=//' | tr -d '"')"
    revision="$(grep -E '^revision=' "$tmpl" | head -1 | sed 's/^revision=//' | tr -d '"')"
    short_desc="$(grep -E '^short_desc=' "$tmpl" | head -1 | sed 's/^short_desc=//' | tr -d '"')"
    homepage="$(grep -E '^homepage=' "$tmpl" | head -1 | sed 's/^homepage=//' | tr -d '"')"
    restricted="$(grep -E '^restricted=' "$tmpl" | head -1 | sed 's/^restricted=//' | tr -d '"')"

    [ -z "$version" ] && continue

    pkgver="${version}_${revision:-1}"

    nonfree_class=""
    [ -n "$restricted" ] && nonfree_class=" nonfree"

    href="${homepage:-$GITHUB_URL}"

    PKG_ITEMS="${PKG_ITEMS}
        <a class=\"pkg-item\" href=\"${href}\">
          <span class=\"pkg-icon\">#</span>
          <span class=\"pkg-name${nonfree_class}\">${pkgname}</span>
          <span class=\"pkg-version\">${pkgver}</span>
          <span class=\"pkg-desc\">${short_desc}</span>
        </a>"
done

cat > "$OUT_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>solocco-void-packages</title>
<style>
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  :root{--bg:#0d1117;--bg-alt:#161b22;--surface:#1c2128;--border:#30363d;--text:#e6edf3;--text-muted:#8b949e;--green:#3fb950;--cyan:#58a6ff;--orange:#d29922;--red:#f85149;--radius:8px}
  html{scroll-behavior:smooth}
  ::selection{background:rgba(88,166,255,0.25)}
  ::-webkit-scrollbar{width:6px}
  ::-webkit-scrollbar-track{background:transparent}
  ::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px}
  body{font-family:'SF Mono','Cascadia Code','Fira Code','JetBrains Mono','Consolas',monospace;background:#010409;color:var(--text);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;line-height:1.65;font-size:14px}
  .terminal{width:100%;max-width:820px;background:var(--bg);border:1px solid var(--border);border-radius:12px;overflow:hidden;box-shadow:0 16px 64px rgba(0,0,0,0.5)}
  .term-bar{display:flex;align-items:center;gap:10px;padding:12px 16px;background:var(--bg-alt);border-bottom:1px solid var(--border);user-select:none}
  .dot{width:12px;height:12px;border-radius:50%}
  .dot-r{background:#f85149}.dot-y{background:#d29922}.dot-g{background:#3fb950}
  .term-title{font-size:.8rem;color:var(--text-muted);margin-left:6px;flex:1;text-align:center}
  .term-body{padding:28px 28px 20px;overflow-x:hidden}
  .line{margin-bottom:6px;display:flex;flex-wrap:wrap;align-items:baseline;gap:8px}
  .line .prompt{color:var(--green);user-select:none;flex-shrink:0}
  .line .cmd{color:var(--cyan)}
  .output{display:block;margin:2px 0 18px 0}
  .output p{color:var(--text-muted);margin:0 0 4px}
  .output p strong{color:var(--text);font-weight:600}
  .divider{border:none;border-top:1px solid var(--border);margin:24px 0}
  pre{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:14px 16px;overflow-x:auto;margin:8px 0 12px;font-size:.85rem}
  pre code{font-family:inherit;color:var(--green);line-height:1.6;white-space:pre}
  pre code .prompt{color:var(--text-muted);user-select:none;margin-right:6px}
  pre code .hl-string{color:var(--orange)}
  .fingerprint{margin:10px 0 0;padding:12px 16px;background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);font-size:.8rem;line-height:1.7;word-break:break-all}
  .fingerprint .label{color:var(--text-muted);user-select:none}
  .fingerprint .signer{color:var(--cyan);font-weight:600}
  .fingerprint .key{display:block;margin-top:4px;color:var(--text);letter-spacing:.04em}
  .pkg-section{margin:10px 0 0}
  .section-label{color:var(--text-muted);font-size:.7rem;text-transform:uppercase;letter-spacing:.08em;padding:6px 0 4px;user-select:none}
  .pkg-scroll{max-height:300px;min-height:52px;overflow-y:auto;margin:6px 0 0}
  .pkg-grid{display:block}
  .pkg-item{display:block;padding:3px 0;text-decoration:none;color:var(--text);line-height:1.55;border-radius:2px;transition:background .1s}
  .pkg-item:hover{background:var(--surface)}
  .pkg-icon{color:var(--cyan);margin-right:2px;user-select:none}
  .pkg-name{font-weight:500}
  .pkg-name.nonfree::after{content:" [nonfree]";color:var(--orange);font-size:.65rem;font-weight:400}
  .pkg-version{color:var(--text-muted);margin-left:4px}
  .pkg-desc{display:block;color:var(--text-muted);font-size:.78rem;padding-left:18px;line-height:1.4}
  .pkg-legend{color:var(--text-muted);font-size:.7rem;margin-top:6px;user-select:none}
  .search-bar{display:block;width:100%;margin:12px 0 0;padding:8px 12px;background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);color:var(--text);font-family:inherit;font-size:.8rem;outline:none;transition:border-color .15s}
  .search-bar:focus{border-color:var(--cyan)}
  .search-bar::placeholder{color:var(--text-muted);user-select:none}
  .cursor-line{margin-top:18px}
  .cursor{display:inline-block;width:8px;height:16px;background:var(--text);animation:blink 1s step-end infinite;vertical-align:text-bottom}
  @keyframes blink{50%{opacity:0}}
  .term-footer{padding:10px 28px 16px;text-align:center;font-size:.75rem;color:var(--text-muted);border-top:1px solid var(--border)}
  .term-footer a{color:var(--cyan);text-decoration:none}
  .term-footer a:hover{text-decoration:underline}
  @media(max-width:640px){body{padding:12px}.term-body{padding:20px 16px 16px}.term-footer{padding:10px 16px 14px}pre{font-size:.8rem;padding:12px}}
  @media(prefers-reduced-motion:reduce){.cursor{animation:none;opacity:1}}
</style>
</head>
<body>
<div class="terminal">
  <div class="term-bar">
    <div class="dot dot-r"></div>
    <div class="dot dot-y"></div>
    <div class="dot dot-g"></div>
    <div class="term-title">solocco@void:~</div>
  </div>
  <div class="term-body">

    <div class="line">
      <span class="prompt">\$</span>
      <span class="cmd">cat README</span>
    </div>
    <div class="output">
      <p>Custom <strong>Void Linux</strong> binary packages</p>
      <p>hosted at <a href="${REPO_URL}" style="color:var(--cyan)">${REPO_URL#https://}</a></p>
    </div>

    <hr class="divider">

    <div class="line">
      <span class="prompt">\$</span>
      <span class="cmd">cat INSTALL</span>
    </div>
    <div class="output">
      <p><strong>1. Add the repository</strong></p>
      <pre><code><span class="prompt">\$</span> echo <span class="hl-string">"repository=${REPO_URL}"</span> | sudo tee /etc/xbps.d/20-solocco.conf</code></pre>
      <p><strong>2. Sync and import the key</strong></p>
      <pre><code><span class="prompt">\$</span> sudo xbps-install -S</code></pre>
      <p>XBPS will ask to import the RSA key. Confirm the signer:</p>
      <div class="fingerprint">
        <span class="label">Signed by:</span> <span class="signer">${SIGNEDBY}</span>
        <span class="key">Run <code style="color:var(--orange)">xbps-query --repository=${REPO_URL} -s ''</code> to verify fingerprint after import.</span>
      </div>
    </div>

    <hr class="divider">

    <div class="line">
      <span class="prompt">\$</span>
      <span class="cmd">ls packages/</span>
    </div>
    <div class="output">
      <input type="text" class="search-bar" placeholder="filter packages..." oninput="filterPackages(this.value)">
      <div class="pkg-section">
        <span class="section-label">packages</span>
        <div class="pkg-scroll"><div class="pkg-grid">
${PKG_ITEMS}
        </div></div>
        <div class="pkg-legend">[nonfree] packages may have licensing restrictions</div>
      </div>
    </div>

    <div class="line cursor-line">
      <span class="prompt">\$</span>
      <span class="cursor"></span>
    </div>
  </div>
  <div class="term-footer">
    <a href="${GITHUB_URL}">GitHub</a> &middot; <a href="keys/pub.pem">Public key</a>
  </div>
</div>
<script>
function filterPackages(q) {
  q = q.toLowerCase();
  document.querySelectorAll('.pkg-item').forEach(function(el) {
    var name = el.querySelector('.pkg-name').textContent.toLowerCase();
    var desc = el.querySelector('.pkg-desc').textContent.toLowerCase();
    el.style.display = name.indexOf(q) !== -1 || desc.indexOf(q) !== -1 ? '' : 'none';
  });
}
</script>
</body>
</html>
HTMLEOF

echo "Generated $OUT_DIR/index.html"
