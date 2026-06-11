# fust

A portable, static Rust binary that does everything flu.sh does — TUI menus, module fetching, registry, batch mode — in a single zero-dependency executable.

## Quick Start

```sh
# Install (Linux/macOS)
curl -fsSL https://github.com/C-Fu/dev-fu/releases/latest/download/install.sh | sh

# Or download directly
curl -fsSL https://github.com/C-Fu/dev-fu/releases/download/v3.0.0-alpha.1/fust-x86_64-unknown-linux-musl.tar.gz | tar xz
chmod +x fust && mv fust ~/.local/bin/
```

## Usage

```sh
fust                  # Interactive TUI menu
fust --list           # List available modules
fust --list --json    # JSON output
fust --install go,rust,starship --yes   # Batch install
fust --remove go      # Batch remove
```

## Build from Source

```sh
cd fust
cargo build --release
```

### Cross-Compilation

```sh
# Install target + zig (for Linux static builds)
rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-musl armv7-unknown-linux-musleabihf
cargo install cargo-zigbuild

# Build all Linux targets
cargo zigbuild --release --target x86_64-unknown-linux-musl
cargo zigbuild --release --target aarch64-unknown-linux-musl
cargo zigbuild --release --target armv7-unknown-linux-musleabihf
```

## Supported Platforms

| Target | Platform | Binary Size |
|--------|----------|-------------|
| x86_64-unknown-linux-musl | Linux x64 (static) | 2.7MB |
| aarch64-unknown-linux-musl | Linux ARM64 (static) | 2.3MB |
| armv7-unknown-linux-musleabihf | Linux ARMv7 / Raspberry Pi (static) | 2.2MB |
| x86_64-apple-darwin | macOS Intel | ~3MB |
| aarch64-apple-darwin | macOS Apple Silicon | ~3MB |

## Architecture

```
src/
  cli.rs         clap CLI argument parsing
  platform.rs    OS/distro/pkg_mgr/arch detection
  tui/           Terminal guard, theme, box drawing, keyboard input
  tui/widgets/   Interactive widgets (select, checklist, radio, yesno, text_input)
  navigation.rs  Hierarchical 3-level menu tree
  tui/widgets/menu.rs  Menu widget with breadcrumbs and queue
  fetch.rs       HTTP fetch with retry, SHA256 verification, disk cache
  metadata.rs    Module header parser (@name, @platforms, @params, @timeout)
  execute.rs     Isolated module execution with timeout + TSV logging
  registry.rs    Community module registry fetch/cache/merge
  logo.rs        ASCII art splash screen
  error.rs       Exit code classification with actionable hints
  menu.rs        menu.db parser with table and JSON output
```

## Dependencies

All dependencies are pure Rust (no system libraries required):

- **ratatui + crossterm** — Terminal UI rendering
- **clap** — CLI argument parsing (derive)
- **reqwest + rustls-tls** — HTTP client (no OpenSSL)
- **sha2 + hex** — SHA256 checksum verification
- **serde + serde_json** — JSON parsing
- **signal-hook** — Unix signal handling
- **anyhow** — Error handling

## License

Same as dev-fu.
