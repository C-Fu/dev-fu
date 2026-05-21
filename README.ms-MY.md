# dev-fu — Satu sekerip untuk siap sedia dev environment dalam 99% mesen engkorang

**Satu sekerip untuk menyediakan mesin pembangun yang lengkap (lebih kurang), di mana-mana sahaja.**

```bash
# Linux / macOS / WSL2 (bash, zsh)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```sh
# Alpine / BusyBox / ash / sh (tiada process substitution)
curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh
```

```powershell
# Windows (PowerShell) - bypasses execution policy for unsigned scripts
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression
```

## Mengapa dev-fu

- **Tiada kebergantungan** - Hanya Bash 4+ dan PowerShell 5.1+. Tiada Python, tiada Node, tiada rangka kerja diperlukan untuk menjalankan skrip itu sendiri. Semua yang dipasang diambil dari sumber rasmi.
- **Boleh dijalankan di mana-mana** - Skrip yang sama berfungsi pada WSL2, Linux, macOS, Chromebook, Android (Termux) dan Windows (PowerShell). Menyokong x86, x64, ARM (Raspberry Pi, Apple Silicon) dan pelayan fizikal. Diuji dalam bekas LXC, mesin maya dan ChromeOS Crostini. Serasi dengan Bash dan ZSH pada Unix, PowerShell pada Windows.
- **Multi-distro** - Mengesan pengurus pakej anda secara automatik (apk, apt, dnf, pacman, zypper, brew, winget, choco). Berfungsi pada Alpine, Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, macOS, ChromeOS, Android (Termux) dan Windows.
- **Menu multi-pilih** - Pilih beberapa operasi dalam satu langkah. Pasang Go, Rust dan Python tanpa perlu jalankan skrip semula.
- **Operasi atomik** - Setiap pemasangan mempunyai pilihan keluarkan yang sepadan. Setiap operasi mengesahkan sebelum meneruskan.

## Platform yang disokong

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

## Apa Yang Boleh Dipasang

| Kategori | Alat |
|----------|------|
| **Containers** | Docker |
| **Rangkaian** | Avahi Daemon + systemd-resolved - mDNS/NSS penemuan nama hos dan DNS (Linux sahaja) |
| **Bahasa** | Go, Rust, Python (dengan pip, pipx, uv), Node.js (LTS melalui nvm), PHP |
| **Runtimes** | Bun |
| **Pengurus Pakej** | Yarn, Composer (PHP), npm |
| **Pembangunan Web** | Pemasang Laravel (melalui Composer) |
| **Alat AI** | OpenCode, GSD (Rokicool), OpenChamber |
| **Produktiviti** | Fancy Prompt - penambahbaikan shell pilihan |
| **Terminal** | Lumpuhkan pelaporan tetikus - mengelakkan acara tetikus mengganggu alat baris arahan |
| **Diagnostik** | Status Check - tunjuk alat dan versi yang dipasang; Compare With Latest - ambil versi terkini dari GitHub/npm/go.dev/nodejs.org dan tunjuk alat mana perlu dikemas kini |

## Prasyarat

- Shell yang serasi POSIX (bash, zsh, ash, sh) - atau PowerShell 5.1+ pada Windows  
- curl atau wget untuk muat turun  
- Keistimewaan sudo (untuk pemasangan pakej sistem)  
- Sambungan Internet

**NOTA:** Untuk WSL2, jalankan di dalam pengedaran Linux, bukan PowerShell.

## Mula Pantas

```bash
# Option 1: Clone and run
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
bash fu.sh

# Option 2: Run directly from remote (no clone needed)
# Berfungsi dari mana-mana shell (sh, ash, zsh, fish) — hanya perlukan bash
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)

# Option 3: Alpine / BusyBox / ash (tiada process substitution)
curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh
```

```powershell
# Windows (PowerShell) - bypasses execution policy
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression
```

## Cara Guna

Jalankan `./fu.sh` dan pilih pilihan dari menu interaktif:

```
 1)  Status Check
 2)  Compare With Latest
 3)  Upgrade All Tools
 4)  Set GitHub Token
 5)  Install Docker
 6)  Create Fancy Prompt (Purple-Pink)
 7)  Create Fancy Prompt (Shades of Blue)
 8)  Install Hostname Discovery (Linux only)
 9)  Install Go
10)  Install Rust
11)  Install Python + Pip + UV + Pipx
12)  Install NVM + Node LTS
13)  Install Bun
14)  Install Yarn
15)  Disable Mouse Reporting in Terminal
16)  Install PHP + Laravel
17)  Install Tailscale
18)  Install OpenCode + GSD (Rokicool) + OpenChamber
```

- **Multi-select:** Masukkan nombor yang dipisahkan koma atau ruang (contoh `7,8 9` untuk pasang Go, Rust dan Python bersama)  
- **Remove:** Awalkan dengan `-` (contoh `-4` untuk keluarkan Docker)  
- **Banding versi:** Pilihan 2 mengambil versi terkini dari internet dan membandingkannya dengan pemasangan tempatan anda
- **Upgrade all:** Tekan `u` pada prompt
- **Quit:** Tekan `q`

Pilihan yang perlu dipilih sendiri sahaja (Hostname Discovery, OpenCode+GSD) mesti digunakan bersendirian.

## Nota Mengikut Platform

### Linux

Semua pengurus pakej disokong. Skrip mengesan pengurus pakej anda secara automatik.

Pilihan 7 (Hostname Discovery) memasang `avahi-daemon` untuk mDNS/NSS dan `systemd-resolved` untuk resolusi DNS, kemudian membuat pautan simbolik `/etc/resolv.conf` ke stub systemd-resolved. Pilihan ini adalah untuk Linux sahaja dan tidak tersedia pada macOS, Windows atau WSL.

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
- Bekas berasaskan Debian dengan `apt` - semua alat berfungsi  
- Docker berjalan dalam VM Crostini (tiada virtualisasi bersarang diperlukan)  
- Pilihan 7 mungkin tidak berfungsi jika systemd tidak tersedia

### Android (Termux)

- Pasang Termux dari F-Droid atau keluaran GitHub  
- Menggunakan `pkg` (apt-based) sebagai pengurus pakej  
- Tiada `sudo` diperlukan - Termux berjalan sebagai satu pengguna  
- Pilihan 7 tidak tersedia (tiada systemd)  
- Sesetengah alat (Docker, PHP) mempunyai sokongan terhad pada Android

## FAQ - Penyelesaian Masalah

### "command not found"

Sesetengah alat dipasang ke `~/.cargo/bin`, `~/.bun/bin` atau `~/.nvm/versions/node/`. Tambah ke PATH:

```bash
source ~/.cargo/env    # Rust
export PATH="$HOME/.bun/bin:$PATH"  # Bun
source ~/.nvm/nvm.sh   # Node
```

### Permission denied

```bash
chmod +x fu.sh
```

### Network issues

Skrip termasuk logik cuba semula (3 attempts, 2s delay). Untuk pemasangan manual, rujuk dokumentasi pemasangan alat masing-masing.

## Exit Codes

- 0 - Success
- 1 - Error (check error message kalau nak tau sebab dia)
- 2 - Option salah

## License

MIT
