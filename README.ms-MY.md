# dev-fu — Satu sekerip untuk siap sedia dev environment dalam 99% mesen engkorang ([English](README.md))

[![POSIX sh](https://img.shields.io/badge/POSIX-sh-4EAA25?style=flat&logo=gnu-bash&logoColor=white)](https://github.com/C-Fu/dev-fu/blob/flu.sh/flu.sh)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Dua skrip, satu matlamat. **`flu.sh`** adalah sistem TUI modular baharu dengan menu bersarang dan pengambilan modul atas permintaan. **`fu.sh`** adalah pemasang monolitik yang teruji. Kedua-duanya tiada kebergantungan, sedia curl-pipe-bash — berjalan pada mana-mana shell POSIX (bash, zsh, dash, ash, busybox) merentasi 10+ distro Linux, macOS, WSL2, Chromebook, dan Android (Termux).

> **`fu.sh`** (skrip monolitik asal) masih tersedia — lihat [README-Fu.ms-MY.md](README-Fu.ms-MY.md) untuk dokumentasi `fu.sh`.

## Mula Pantas flu.sh

```bash
# Option 1: curl-pipe-bash (bash / zsh / mana-mana shell POSIX)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/flu.sh)
```

```sh
# Option 1 alt: BusyBox / dash / ash (tiada process substitution)
curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/flu.sh -o /tmp/flu.sh && sh /tmp/flu.sh
```

```bash
# Option 2: Klon dan jalankan secara tempatan (tiada rangkaian diperlukan selepas klon)
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
./flu.sh
```

> **Windows:** Gunakan `flu.ps1` untuk PowerShell asli. POSIX `flu.sh` berfungsi dalam WSL2 (jalankan di dalam pengedaran Linux, bukan PowerShell).

## Ciri-ciri flu.sh

- **Tiada kebergantungan** — POSIX `sh` tulen. Tiada Python, tiada Node, tiada rangka kerja diperlukan untuk menjalankan skrip itu sendiri.
- **ANSI TUI** — Navigasi anak panah dengan jejak breadcrumb dan logo ASCII dev-fu magenta semasa permulaan.
- **Submenu bersarang 3 peringkat** — Kategori → Subkategori → Pilihan, dengan pintasan papan kekunci (`q` keluar, `b` kembali).
- **Seni bina modular jauh** — Setiap pilihan menu mengambil dan melaksanakan skrip `sh` POSIX kendiri dari GitHub atas permintaan. Dalam mod tempatan (`git clone`), modul dijalankan dari cakera — tiada rangkaian diperlukan.
- **Serasi POSIX sh** — Diuji pada bash 4+, zsh, dash, ash (Alpine/BusyBox).
- **Pengesanan platform** — Auto-kesan OS, distro, pengurus pakej, dan seni bina CPU semasa permulaan.
- **19 operasi merentasi 5 kategori** — Kebanyakan operasi pemasangan mempunyai pilihan keluarkan yang sepadan.

## Struktur Menu flu.sh

```
flu.sh v1.1
├── 🔍 Diagnostics
│   ├── 🔍 Status Check
│   ├── 🔄 Compare With Latest
│   └── ⬆️  Upgrade All Tools
├── 🐹 Languages & Runtimes
│   ├── 🐹 Go (install/remove)
│   ├── 🦀 Rust (install/remove)
│   ├── 🐍 Python + Pip + UV + Pipx (install/remove)
│   ├── 💚 NVM + Node LTS (install/remove)
│   ├── 🥟 Bun (install/remove)
│   └── 🐘 PHP + Laravel (install/remove)
├── 🛠 Tools
│   ├── 🧶 Yarn (install/remove)
│   ├── 🐳 Docker (install/remove)
│   ├── 🛜 Tailscale (install/remove)
│   └── 🤖 OpenCode + GSD + OpenChamber
├── 🐚 Shell
│   ├── 💜 Fancy Prompt (Purple-Pink) (create/remove)
│   ├── 💙 Fancy Prompt (Shades of Blue) (create/remove)
│   └── 🏠 Hostname Discovery — Linux (install/remove)
└── ⚙️ Settings
    ├── 🔑 Set GitHub Token
    ├── 🖱  Disable Mouse Reporting
    └── 🖱  Enable Mouse Reporting
```

## Seni Bina Modul

flu.sh menggunakan sistem modul jauh atas permintaan. Setiap pilihan menu dipetakan kepada skrip `sh` POSIX kendiri di bawah `modules/`. Apabila flu.sh dijalankan:

1. **`tui.sh`** — Primitif paparan terminal ANSI (kedudukan kursor, warna, input papan kekunci)
2. **`menu.sh`** — Menghurai `menu.db` (DSL menu dipisahkan paip) dan memaparkan TUI interaktif
3. **`modules.sh`** — Mengendalikan pengambilan skrip jauh dari GitHub dan pelaksanaan tempatan

### Bagaimana Modul Berfungsi

- **Mod tempatan:** `git clone` dan jalankan — modul diambil dari cakera dalam `modules/`, tiada rangkaian diperlukan
- **Mod jauh:** `curl-pipe-bash` — modul diambil atas permintaan dari URL mentah GitHub dengan 3 kali cuba semula (kelewatan 2s)
- **Persekitaran:** Modul menggunakan `FLU_OS`, `FLU_DISTRO`, `FLU_PKG_MGR`, `FLU_ARCH` untuk pemasangan mengikut platform
- **Keselamatan:** Semua modul menggunakan `set -eu`, pengawal idempoten (`command -v`), dan `_maybe_sudo()` untuk peningkatan keistimewaan hanya apabila diperlukan
- **Kontrak:** Setiap skrip modul mengandungi pengepala metadata terhurai (`@name`, `@platforms`, `@deps`, `@timeout`) dan mengikuti konvensyen kod keluar yang ketat (0 = berjaya, 1 = gagal)

### Kategori Modul

| Kategori | Skrip Modul | Bilangan |
|----------|-------------|----------|
| Bahasa & Runtimes | `install_go.sh`, `install_rust.sh`, `install_python.sh`, `install_nvm_node.sh`, `install_bun.sh`, `install_php_laravel.sh` (+ skrip keluarkan sepadan) | 12 |
| Alatan | `install_docker.sh`, `install_tailscale.sh`, `install_yarn.sh`, `install_opencode_gsd.sh` (+ skrip keluarkan sepadan) | 7 |
| Shell | `create_fancy_prompt.sh`, `create_fancy_prompt_blue.sh`, `install_avahi.sh` (+ skrip keluarkan sepadan) | 6 |
| Diagnostik | `status_check.sh`, `status_check_compare.sh`, `upgrade_all.sh` | 3 |
| Tetapan | `set_github_token.sh`, `configure_mouse_disable.sh`, `configure_mouse_enable.sh` | 3 |

**Jumlah: 31 skrip modul.** Lihat [modules/README.md](modules/README.md) untuk pendaftaran ID tindakan penuh dan spesifikasi kontrak modul.

### Gambarajah Seni Bina

```
curl-pipe-bash / git clone
        │
        ▼
    flu.sh ─── pengaturcara
        │
   ┌────┼────────────┐
   ▼    ▼            ▼
tui.sh  menu.sh  modules.sh
   │     │           │
   │     ▼           ▼
   │  menu.db    modules/*.sh
   │  (DSL)    (pengambilan atas permintaan)
   ▼
   Paparan TTY
   (kod escape ANSI)
```

## fu.sh — Skrip Monolitik Legasi

flu.sh adalah sistem TUI modular generasi seterusnya. Skrip monolitik asal `fu.sh` masih tersedia dengan 18 operasi menu rata dan didokumenkan secara berasingan — lihat **[README-Fu.ms-MY.md](README-Fu.ms-MY.md)** untuk dokumentasi `fu.sh`, termasuk antara muka prompt bernombor, mod CLI tidak interaktif, dan nota mengikut platform.

| Ciri | `flu.sh` | `fu.sh` |
|------|----------|---------|
| Shell | POSIX `sh` (bash, zsh, dash, ash, busybox) | Bash 4+ |
| UI | TUI ANSI dengan navigasi anak panah | Prompt senarai bernombor |
| Kedalaman Menu | Submenu bersarang 3 peringkat | Rata (18 pilihan) |
| Seni Bina | Modular (skrip jauh atas permintaan) | Monolitik (semua logik dalam satu fail) |
| Sumber Modul | Direktori `modules/` (tempatan) atau GitHub (jauh) | Fungsi sebaris |
| Operasi | 19 merentasi 5 kategori | 18 operasi rata |
| Keserasian POSIX | Penuh (dash, ash, busybox) | Bash sahaja |

## Mengapa dev-fu

- **Tiada kebergantungan** — POSIX `sh` tulen dan PowerShell 5.1+. Semua yang dipasang diambil dari sumber rasmi.
- **Boleh dijalankan di mana-mana** — Skrip yang sama merentasi 10+ distro Linux, macOS, WSL2, Chromebook, Android (Termux), dan Windows (PowerShell). Diuji dalam bekas LXC, mesin maya, dan ChromeOS Crostini.
- **Multi-distro** — Auto-kesan 6 pengurus pakej (apk, apt, dnf, pacman, zypper, brew). Berfungsi pada Alpine, Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, macOS, dan Termux.
- **Seni bina modular** — Skrip jauh atas permintaan dalam `flu.sh`. Klon dan jalankan secara tempatan untuk operasi tanpa rangkaian.
- **Operasi kelompok** — `upgrade_all.sh` menatar semua alat yang dipasang dalam satu laluan. Status Check menunjukkan semua versi yang dipasang. Compare With Latest menyemak kemas kini.

## Platform yang Disokong

flu.sh serasi POSIX `sh` dan diuji pada:

| Shell | Sokongan TUI |
|-------|-------------|
| bash 4+ | Penuh |
| zsh | Penuh |
| dash (lalai Debian) | Penuh |
| ash (Alpine/BusyBox) | Penuh |

| Platform | Pengurus Pakej | Seni Bina |
|----------|----------------|-----------|
| Alpine Linux | apk | x86_64, ARM |
| Debian / Ubuntu | apt | x86_64, ARM |
| Fedora / RHEL | dnf | x86_64, ARM |
| Arch Linux | pacman | x86_64, ARM |
| openSUSE | zypper | x86_64, ARM |
| macOS (Intel & Apple Silicon) | Homebrew | x64, ARM |
| WSL2 (Ubuntu, Debian) | apt | x86_64, ARM |
| Chromebook (Crostini) | apt | x86_64, ARM |
| Android (Termux) | pkg | ARM, x86_64 |
| Raspberry Pi (Pi OS, Ubuntu) | apt | ARM |

> **Windows asli:** Gunakan `flu.ps1` (PowerShell). Untuk WSL2, jalankan `flu.sh` di dalam pengedaran Linux.

## Nota Mengikut Platform

### Alpine / BusyBox

- **NVM + Node LTS** memasang Node.js terus melalui `apk add nodejs npm` dan bukannya NVM. Perpustakaan musl libc pada Alpine tidak serasi dengan binari Node pra-binaan NVM.
- **Docker** menggunakan `apk add docker docker-cli-compose` kerana skrip pemasangan rasmi Docker tidak menyokong Alpine.

### macOS

- Memerlukan [Homebrew](https://brew.sh/) — skrip auto-kesan `brew` sebagai pengurus pakej.
- Node dipasang melalui NVM, bukan Node sistem.

### WSL2

- Jalankan `flu.sh` di dalam pengedaran Linux WSL, bukan dari PowerShell.
- Berfungsi dengan Docker Desktop WSL2 backend.

### Chromebook (ChromeOS Crostini)

- Aktifkan Linux (Crostini) dalam **Settings > Advanced > Developers** ChromeOS.
- Bekas berasaskan Debian dengan `apt` — semua alat berfungsi.
- Docker berjalan dalam VM Crostini (tiada virtualisasi bersarang diperlukan).
- Hostname Discovery mungkin tidak berfungsi jika systemd tidak tersedia.

### Android (Termux)

- Pasang [Termux](https://termux.dev/) dari F-Droid atau keluaran GitHub.
- Menggunakan `pkg` (berasaskan apt). Tiada `sudo` diperlukan — Termux berjalan sebagai pengguna tunggal.
- Hostname Discovery tidak tersedia (tiada systemd).
- Sesetengah alat (Docker, PHP) mempunyai sokongan terhad pada Android.

### ARM (Apple Silicon, Raspberry Pi)

- Sokongan binaan ARM untuk semua alat. Bun, Go, Rust mempunyai binari ARM asli.

## Penyelesaian Masalah

### "command not found" selepas pemasangan

Sesetengah alat dipasang ke laluan tidak standard. Tambah ke profil shell anda:

```bash
export PATH="$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.local/bin:$PATH"
source ~/.cargo/env     # Rust
source ~/.nvm/nvm.sh    # Node.js (NVM)
```

### Terminal tidak dipulihkan selepas keluar

Tekan `Ctrl+C` atau jalankan `reset`. flu.sh mempunyai pembersihan selamat isyarat melalui `_flu_cleanup_exit()` yang memulihkan tetapan terminal pada setiap laluan keluar (normal, ralat, atau isyarat).

### Pengambilan modul gagal (ralat rangkaian)

flu.sh cuba semula 3 kali dengan kelewatan 2 saat. Untuk persekitaran dengan rangkaian tidak stabil, klon repositori dan jalankan secara tempatan:

```bash
git clone https://github.com/C-Fu/dev-fu.git && cd dev-fu && ./flu.sh
```

### "No such file" pada curl-pipe-bash

BusyBox dan dash tidak menyokong process substitution (`<(curl ...)`). Gunakan bentuk alternatif:

```sh
curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/flu.sh -o /tmp/flu.sh && sh /tmp/flu.sh
```

### Permission denied

```bash
chmod +x flu.sh
```

### TUI tidak dipaparkan (teks berselerak)

Pastikan terminal anda menyokong kod escape ANSI. Kebanyakan terminal moden menyokongnya — cuba `xterm-256color` atau `screen-256color` sebagai tetapan `TERM` anda. Untuk persekitaran sangat minimal (bare `dash` tanpa TTY), flu.sh beralih kepada prompt bernombor teks biasa.

## License

MIT
