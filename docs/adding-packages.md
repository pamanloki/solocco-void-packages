# Nambah paket ke repo ini

Panduan ringkas biar bisa nambah paket sendiri tanpa nanya AI.

## Alur singkat

```
scaffold template  ->  isi bagian TODO (kalau ada)  ->  commit + push  ->  CI build + publish
```

Ada 2 cara bikin template. **Selalu coba cara 1 dulu.**

> **Tanpa terminal (dari HP/browser):** buka tab **Actions -> "Add package"
> -> Run workflow**, isi form-nya (nama paket, mode, dll), klik Run. Workflow
> bakal scaffold + commit + push + trigger build otomatis. Sama persis kayak
> jalanin `new-template.sh` di bawah, tapi lewat UI GitHub.

---

## Cara 1 (paling gampang): contek dari void

Kalau void-linux udah punya paketnya, ambil template asli mereka — udah
lengkap (`depends`, `build_style`, `do_install`), tinggal pakai:

```bash
scripts/new-template.sh --from-void <nama-paket>
# contoh:
scripts/new-template.sh --from-void neofetch
scripts/new-template.sh --from-void mpv --build false
```

Ini otomatis:
- nyalin `srcpkgs/<nama>/template` dari void,
- daftarin ke `packages.json` (strategy `source-tarball` kalau distfiles-nya
  GitHub archive, selain itu `static`).

Kalau outputnya ngingетin soal folder `files/` atau `patches/`, ambil manual
dari halaman void: `github.com/void-linux/void-packages/tree/master/srcpkgs/<nama>`.

Habis itu tinggal `git add … && git commit && git push`. Checksum udah dari
void, biasanya langsung lolos build.

---

## Cara 2: void gak punya -> scaffold manual

```bash
# aplikasi dari source (build sendiri)
scripts/new-template.sh --name foo --strategy source-tarball \
  --repo owner/foo --version 1.2.3 --build-style gnu-configure \
  --desc "Foo does X" --license MIT

# binary jadi dari GitHub Releases (gak di-compile)
scripts/new-template.sh --name foo-bin --strategy binary-asset \
  --repo owner/foo --version 1.2.3 --asset "foo-{version}-x86_64.tar.gz" --url-v-prefix

# icon theme model vinceliuice
scripts/new-template.sh --name Bar-icon-theme --strategy icon-theme \
  --repo vinceliuice/Bar-icon-theme --tag 2026-09-10
```

Checksum diisi placeholder (64 nol) — **gak usah dihitung manual**. Build
pertama bakal gagal "SHA256 mismatch", terus job autofix di CI otomatis nulis
checksum yang bener + rebuild. (Kecuali `font` yang punya 2 checksum:
jalanin `scripts/update.sh` buat ngisinya, atau tunggu Update Check harian.)

Habis scaffold, isi bagian `# TODO` di template (lihat di bawah).

---

## Arti field template

| Field | Kapan dibutuhin | Contoh isi |
|---|---|---|
| `hostmakedepends` | alat buat **nge-build** | `pkg-config cmake clang git` |
| `makedepends` | library `-devel` buat **compile/link** | `qt6-base-devel libpng-devel` |
| `depends` | yang harus ada pas paket **jalan** | `qt6-wayland hicolor-icon-theme` |
| `build_style` | cara build standar (auto `make install`) | `cmake` `meson` `gnu-configure` `go` `cargo` `python3-module` |
| `do_install()` | perintah manual naruh file ke `$DESTDIR` | lihat binary-asset di bawah |

### Yang SERING gak perlu diisi

- **`depends` boleh dikosongin** untuk kebanyakan lib. xbps otomatis deteksi
  shared library dari binary hasil build. Isi `depends` cuma buat yang gak
  ke-detect: program lain yang dipanggil saat runtime, font, data, dll.
- **`do_install()` gak perlu** kalau pakai `build_style` (cmake/meson/…),
  karena `make install` jalan otomatis. Isi `do_install` cuma buat
  `binary-asset` (naruh file prebuilt) atau build non-standar.

### Contoh `do_install` (binary-asset)

```bash
do_install() {
	vbin foo                       # pasang executable ke /usr/bin
	vinstall foo.desktop 644 usr/share/applications
	vinstall icon.png 644 usr/share/pixmaps foo.png
}
```
Helper umum: `vbin`, `vcopy`, `vinstall <file> <mode> <dir>`, `vmkdir`,
`vlicense`, `vman`, `vdoc`.

---

## Cara nyari isi `depends`/`makedepends`

1. Baca README/INSTALL upstream bagian "Dependencies" / "Building".
2. Contek template void yang mirip:
   `raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/<nama>/template`
3. Kalau build gagal karena header/lib gak ketemu, error-nya nyebut nama
   yang kurang — tambahin `-devel`-nya ke `makedepends`.

---

## Setelah push

CI otomatis: build → autofix checksum (kalau perlu) → publish → smoke test.
Kalau ada yang gagal, notif Telegram bakal masuk. Paket yang belum kebuild
juga bakal di-retry sama job reconcile harian. Jadi habis push, tinggal
tungguin aja.
