# dev-fu — Satu sekerip untuk siap sedia dev environment dalam 99% mesen engkorang

**Satu sekerip untuk menyediakan mesin pembangun yang lengkap (lebih kurang), di mana-mana sahaja.**

```bash
# Linux / macOS / WSL2
bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```powershell
# Windows (PowerShell) - bypasses execution policy for unsigned scripts
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1 | Invoke-Expression
```

## Mengapa dev-fu

- **Tiada kebergantungan** - Hanya Bash 4+ dan PowerShell 5.1+. Tiada Python, tiada Node, tiada rangka kerja diperlukan untuk menjalankan skrip itu sendiri. Semua yang dipasang diambil dari sumber rasmi.
- **Boleh dijalankan di mana-mana** - Skrip yang sama berfungsi pada WSL2, Linux, macOS, Chromebook, Android (Termux) dan Windows (PowerShell). Menyokong x86, x64, ARM (Raspberry Pi, Apple Silicon) dan pelayan fizikal. Diuji dalam bekas LXC, mesin maya dan ChromeOS Crostini. Serasi dengan Bash dan ZSH pada Unix, PowerShell pada Windows.
- **Multi-distro** - Mengesan pengurus pakej anda secara automatik (apk, apt, dnf, pacman, zypper, brew, winget, choco). Berfungsi pada Alpine, Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, macOS, ChromeOS, Android (Termux) dan Windows.
- **Menu multi-pilih** - Pilih beberapa operasi dalam satu langkah. Pasang Go, Rust dan Python tanpa perlu jalankan skrip semula.
- **Operasi atomik** - Setiap pemasangan mempunyai pilihan keluarkan yang sepadan. Setiap operasi mengesahkan sebelum meneruskan.

## Platform yang disokong

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

## Prasyarat

- Shell yang serasi POSIX (bash, zsh) - atau PowerShell 5.1+ pada Windows  
- curl atau wget untuk muat turun  
- Keistimewaan sudo (untuk pemasangan pakej sistem)  
- Sambungan Internet

**NOTA:** Untuk WSL2, jalankan di dalam pengedaran Linux, bukan PowerShell.

## Mula Pantas

```bash
# Option 1: Clone and run
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
./fu.sh

# Option 2: Run directly from remote (no clone needed)
bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

## Cara Guna

Jalankan `./fu.sh` dan pilih pilihan dari menu interaktif:

```
 1)  Status Check
 2)  Compare With Latest
 3)  Upgrade All Tools
 4)  Install Docker
 5)  Create Fancy Prompt
 6)  Install Hostname Discovery (Linux only)
 7)  Install Go
 8)  Install Rust
 9)  Install Python + Pip + UV + Pipx
10)  Install NVM + Node LTS
11)  Install Bun
12)  Install Yarn
13)  Disable Mouse Reporting in Terminal
14)  Install PHP + Laravel
15)  Install OpenCode + GSD (Rokicool) + OpenChamber
```

- **Multi-select:** Masukkan nombor yang dipisahkan koma atau ruang (contoh `6,7 8` untuk pasang Go, Rust dan Python bersama)  
- **Remove:** Awalkan dengan `-` (contoh `-3` untuk keluarkan Docker)  
- **Upgrade all:** Tekan `u` pada prompt  
- **Quit:** Tekan `q`

Pilihan yang perlu dipilih sendiri sahaja (Hostname Discovery, OpenCode+GSD) mesti digunakan bersendirian.

## Nota Mengikut Platform

### Linux

Semua pengurus pakej disokong. Skrip mengesan pengurus pakej anda secara automatik.

Pilihan 6 (Hostname Discovery) memasang `avahi-daemon` untuk mDNS/NSS dan `systemd-resolved` untuk resolusi DNS, kemudian membuat pautan simbolik `/etc/resolv.conf` ke stub systemd-resolved. Pilihan ini adalah untuk Linux sahaja dan tidak tersedia pada macOS, Windows atau WSL.

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
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1 | Invoke-Expression

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
- Pilihan 6 mungkin tidak berfungsi jika systemd tidak tersedia

### Android (Termux)

- Pasang Termux dari F-Droid atau keluaran GitHub  
- Menggunakan `pkg` (apt-based) sebagai pengurus pakej  
- Tiada `sudo` diperlukan - Termux berjalan sebagai satu pengguna  
- Pilihan 6 tidak tersedia (tiada systemd)  
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
