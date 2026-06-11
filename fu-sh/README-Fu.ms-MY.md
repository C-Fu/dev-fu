# fu.sh — Bootstrap Dev Environment Monolitik ([English](README-Fu.md))

> 📖 **Ini adalah dokumentasi legasi.** Untuk projek utama, lihat [README.ms-MY.md](README.ms-MY.md) — sistem TUI modular flu.sh.

## Mula Pantas (curl-pipe-bash)

```bash
# fu.sh — monolithic (bash / zsh)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```sh
# sh / ash / BusyBox (tiada process substitution)
curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh
```

```powershell
# Windows (PowerShell) — bypasses execution policy untuk skrip tidak ditandatangani
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression
```

## Skrinshot

```
://─────────────── System Info ────────────────║
│ Architecture: x86_64
│ OS: alpine
│ Package Mgr: apk
│ Shell: bash
│ WAN IP:
│ LAN IP:
│ Hostname:
│ User: root (0:0)
▉════════════════by═C-Fu════════════════


        ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗
 ██╗   ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║
 ╚═╝  ██╔╝██╔╝ ██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║
 ██╗ ██╔╝██╔╝  ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║
 ╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝
    ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝

://─────────────────────────────║
│ Environment Setup Utility
▉══════════════════════════

│ 1)  🔍  Status Check
│ 2)  🔄  Compare With Latest
│ 3)  ⬆️  Upgrade All Tools
│ 4)  🔑  Set GitHub Token
│ 5)  🐳  Install Docker
│ 6)  ✨  Create Fancy Prompt (Purple-Pink)
│ 7)  💎  Create Fancy Prompt (Shades of Blue)
│ 8)  🌐  Install Hostname Discovery (Linux only)
│ 9)  🐹  Install Go
│ 10) ☢️  Install Rust
│ 11) 🐍  Install Python + Pip + UV + Pipx
│ 12) 📦  Install NVM + Node LTS
│ 13) 🥟  Install Bun
│ 14) ⚡  Install Yarn
│ 15) 🐁  Disable Mouse Reporting in Terminal
│ 16) 🐘  Install PHP + Laravel
│ 17) 🔒  Install Tailscale
│ 18) 🚀  Install OpenCode + GSD (Rokicool) + OpenChamber

  Enter your selected options, split by commas or spaces (1,2 3 4)
  Enter -N to remove (e.g. -3 removes Docker)

://─────────────────────────║
│  Press u to upgrade all
│  Press q to quit
▉══════════════════
▸ Choice:
```

## Mula Pantas

```bash
# Option 1: Klon dan jalankan
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
bash fu.sh
```

```bash
# Option 2: bash (Linux / macOS / WSL2)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```zsh
# Option 2: zsh (lalai macOS)
zsh -c 'bash <(curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)'
```

```sh
# Option 2: sh / dash (lalai Debian)
sh -c 'curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh'
```

```sh
# Option 2: ash / BusyBox (lalai Alpine)
ash -c 'curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh'
```

```fish
# Option 2: fish
bash -c 'bash <(curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)'
```

```powershell
# Windows (PowerShell) — bypasses execution policy
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression
```

## Cara Guna

Jalankan `./fu.sh` dan pilih pilihan dari menu interaktif:

```
 1) 🔍  Status Check
 2) 🔄  Compare With Latest
 3) ⬆️  Upgrade All Tools
 4) 🔑  Set GitHub Token
 5) 🐳  Install Docker
 6) ✨  Create Fancy Prompt (Purple-Pink)
 7) 💎  Create Fancy Prompt (Shades of Blue)
 8) 🌐  Install Hostname Discovery (Linux only)
 9) 🐹  Install Go
10) ☢️  Install Rust
11) 🐍  Install Python + Pip + UV + Pipx
12) 📦  Install NVM + Node LTS
13) 🥟  Install Bun
14) ⚡  Install Yarn
15) 🐁  Disable Mouse Reporting in Terminal
16) 🐘  Install PHP + Laravel
17) 🔒  Install Tailscale
18) 🚀  Install OpenCode + GSD (Rokicool) + OpenChamber
```

- **Multi-select:** Masukkan nombor yang dipisahkan koma atau ruang (contoh `7,8 9` untuk pasang Go, Rust dan Python bersama)
- **Remove:** Awalkan dengan `-` (contoh `-4` untuk keluarkan Docker)
- **Banding versi:** Pilihan 2 mengambil versi terkini dari internet dan membandingkannya dengan pemasangan tempatan anda
- **Upgrade all:** Tekan `u` pada prompt
- **Quit:** Tekan `q`

Pilihan yang perlu dipilih sendiri sahaja (Hostname Discovery, OpenCode+GSD) mesti digunakan bersendirian.

## Mod Tidak Interaktif (CLI)

Lepas nombor pilihan sebagai argumen untuk jalankan tanpa menu interaktif:

```bash
# Tatar semua alat
bash fu.sh u

# Pasang Docker dan Python, keluarkan Go
bash fu.sh 5 11 -9

# Satu baris dari jauh
bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh) 5 11 -9
```

```powershell
# Windows: Tatar semua alat
.\fu.ps1 u

# Pasang Docker dan Python, keluarkan Go
.\fu.ps1 5 11 -9
```

## fu.sh vs flu.sh

| Ciri | `fu.sh` | `flu.sh` |
|------|---------|----------|
| Shell | Bash 4+ | POSIX sh (bash, zsh, dash, ash, busybox) |
| UI | Prompt senarai bernombor | TUI ANSI dengan navigasi anak panah |
| Kedalaman Menu | Rata (18 pilihan) | Submenu bersarang 3 peringkat |
| Seni Bina | Monolitik | Modular (skrip jauh atas permintaan) |
| Sumber Modul | Sebaris dalam skrip | Direktori `modules/` (tempatan) atau GitHub (jauh) |
| Alat terkenal | Docker, Rust, PHP, Tailscale, Fancy Prompt | Python, Node.js, Go, VS Code, Neovim, dll. |
| Jumlah pemasangan | 18 operasi | 12 modul (berkembang) |

## Apa Yang Boleh Dipasang

| Kategori | Alat |
|----------|------|
| **Kontena** | [Docker](https://www.docker.com/) |
| **Rangkaian** | [Avahi Daemon](https://github.com/lathiat/avahi) + [systemd-resolved](https://www.freedesktop.org/wiki/Software/systemd/resolved/) — penemuan nama hos mDNS/NSS + DNS (Linux sahaja) |
| **Bahasa** | [Go](https://go.dev/), [Rust](https://www.rust-lang.org/), [Python](https://www.python.org/) (dengan pip, pipx, uv), [Node.js](https://nodejs.org/) (LTS melalui nvm), [PHP](https://www.php.net/) |
| **Runtimes** | [Bun](https://bun.sh/) |
| **Pengurus Pakej** | [Yarn](https://yarnpkg.com/), [Composer](https://getcomposer.org/) (PHP), npm |
| **Pembangunan Web** | Pemasang [Laravel](https://laravel.com/) (melalui Composer) |
| **Alat AI** | [OpenCode](https://github.com/anomalyco/opencode), [GSD](https://github.com/rokicool/gsd-opencode) (Rokicool), [OpenChamber](https://github.com/rokicool/openchamber) |
| **Produktiviti** | [Fancy Prompt](https://github.com/jonathan-scholbach/fancy-prompt) — penambahbaikan shell pilihan |
| **Terminal** | Lumpuhkan pelaporan tetikus — mengelakkan acara tetikus terminal mengganggu alat CLI |
| **Diagnostik** | Status Check — tunjuk alat dan versi yang dipasang; Compare With Latest — ambil versi terkini dari GitHub/npm/go.dev/nodejs.org dan tunjuk alat mana perlu dikemas kini |

## Platform yang Disokong

<p align="center">
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/WSL2-4A4A4A?style=for-the-badge&logo=windows-terminal&logoColor=white" alt="WSL2">
  <img src="https://img.shields.io/badge/Chromebook-4285F4?style=for-the-badge&logo=google-chrome&logoColor=white" alt="Chromebook">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <br>
  <img src="https://img.shields.io/badge/Alpine-0D597F?style=for-the-badge&logo=alpine-linux&logoColor=white" alt="Alpine">
  <img src="https://img.shields.io/badge/Debian-A80030?style=for-the-badge&logo=debian&logoColor=white" alt="Debian">
  <img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/Fedora-294172?style=for-the-badge&logo=fedora&logoColor=white" alt="Fedora">
  <img src="https://img.shields.io/badge/Arch-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch">
  <br>
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/ZSH-4EAA25?style=for-the-badge&logo=zsh&logoColor=white" alt="ZSH">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
  <img src="https://img.shields.io/badge/BusyBox-293E5A?style=for-the-badge&logo=buzzfeed&logoColor=white" alt="BusyBox">
  <img src="https://img.shields.io/badge/ash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="ash">
  <br>
  <img src="https://img.shields.io/badge/x86__64-6DB33F?style=for-the-badge&logo=amd&logoColor=white" alt="x86_64">
  <img src="https://img.shields.io/badge/ARM64-00C1DE?style=for-the-badge&logo=arm&logoColor=white" alt="ARM64">
  <img src="https://img.shields.io/badge/Raspberry_Pi-C51A4A?style=for-the-badge&logo=raspberry-pi&logoColor=white" alt="Raspberry Pi">
  <img src="https://img.shields.io/badge/LXC-4A4A4A?style=for-the-badge&logo=linux-containers&logoColor=white" alt="LXC">
</p>

| Platform | Seni Bina | Pengurus Pakej | Skrip |
|----------|-----------|----------------|-------|
| Alpine Linux | x86_64, ARM | apk | `fu.sh` |
| Debian / Ubuntu | x86_64, ARM | apt | `fu.sh` |
| Fedora / RHEL | x86_64, ARM | dnf | `fu.sh` |
| Arch Linux | x86_64, ARM | pacman | `fu.sh` |
| openSUSE | x86_64, ARM | zypper | `fu.sh` |
| macOS (Intel & Apple Silicon) | x64, ARM | Homebrew | `fu.sh` |
| WSL2 (Ubuntu, Debian) | x86_64, ARM | apt | `fu.sh` |
| LXC / LXD containers | x86_64, ARM | auto-detected | `fu.sh` |
| Bare metal servers | x86_64, ARM | auto-detected | `fu.sh` |
| Raspberry Pi (Pi OS, Ubuntu) | ARM | apt | `fu.sh` |
| Chromebook (Crostini) | x86_64, ARM | apt (auto-detected) | `fu.sh` |
| Android / Termux | ARM, x86_64 | pkg (apt) | `fu.sh` |
| Windows (native) | x64, ARM | winget / choco | `fu.ps1` |

## Nota Mengikut Platform

### Linux

Semua pengurus pakej disokong. Skrip mengesan pengurus pakej anda secara automatik.

Pilihan 7 (Hostname Discovery) memasang `avahi-daemon` untuk mDNS/NSS dan `systemd-resolved` untuk resolusi DNS, kemudian membuat pautan simbolik `/etc/resolv.conf` ke stub systemd-resolved. Pilihan ini adalah untuk Linux sahaja — tidak tersedia pada macOS, Windows, atau WSL.

### Alpine / BusyBox

- Pilihan 12 (NVM + Node LTS) memasang Node.js terus melalui `apk add nodejs npm` dan bukannya NVM. Perpustakaan musl libc pada Alpine tidak serasi dengan binari Node pra-binaan NVM, dan kompilasi dari sumber sering gagal kerana kekurangan kebergantungan binaan.
- Pilihan 5 (Docker) menggunakan `apk add docker docker-cli-compose` kerana skrip pemasangan rasmi Docker tidak menyokong Alpine.

### macOS

- Memerlukan Homebrew: `brew install bash`
- Node melalui nvm, bukan Node sistem

### WSL2

- Jalankan di dalam persekitaran Linux, bukan PowerShell
- Berfungsi dengan Docker Desktop WSL2 backend

### Windows (PowerShell)

Untuk Windows asli, gunakan `fu.ps1`:

```powershell
# Option 1: Clone and run locally
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
.\fu.ps1

# Option 2: Run directly from remote (bypasses execution policy)
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression

# Option 3: Bypass execution policy for local script
powershell -ExecutionPolicy Bypass -File .\fu.ps1
```

**Nota:** Jika anda melihat ralat "not digitally signed", gunakan Option 2 atau 3 di atas.

### ARM (Apple Silicon, Raspberry Pi)

- Sokongan binaan ARM untuk semua alat
- Bun, Go, Rust mempunyai binari ARM asli

### Chromebook (ChromeOS Crostini)

- Aktifkan Linux (Crostini) dalam Tetapan ChromeOS > Advanced > Developers
- Bekas berasaskan Debian dengan `apt` — semua alat berfungsi
- Docker berjalan dalam VM Crostini (tiada virtualisasi bersarang diperlukan)
- Pilihan 7 (Hostname Discovery) mungkin tidak berfungsi jika systemd tidak tersedia

### Android (Termux)

- Pasang [Termux](https://termux.dev/) dari F-Droid atau keluaran GitHub
- Menggunakan `pkg` (apt-based) sebagai pengurus pakej
- Tiada `sudo` diperlukan — Termux berjalan sebagai pengguna tunggal
- Pilihan 7 (Hostname Discovery) tidak tersedia (tiada systemd)
- Sesetengah alat (Docker, PHP) mempunyai sokongan terhad pada Android

## Penyelesaian Masalah

### "command not found"

Sesetengah alat dipasang ke `~/.cargo/bin`, `~/.bun/bin`, atau `~/.nvm/versions/node/`. Tambah ke PATH:

```bash
source ~/.cargo/env    # Rust
export PATH="$HOME/.bun/bin:$PATH"  # Bun
source ~/.nvm/nvm.sh   # Node
```

### Permission denied

```bash
chmod +x fu.sh
```

### Isu rangkaian

Skrip termasuk logik cuba semula (3 percubaan, kelewatan 2s). Untuk pemasangan manual, rujuk dokumentasi pemasangan alat masing-masing.

## Kod Keluar

- 0 — Berjaya
- 1 — Ralat (semak mesej ralat kalau nak tau sebab dia)
- 2 — Pilihan salah

## License

MIT

---

*Ini adalah dokumentasi legasi fu.sh. Untuk sistem TUI modular, lihat [README.ms-MY.md](README.ms-MY.md).*
