use anyhow::Result;
use std::process::Command;

/// Platform information matching flu.sh's FLU_* environment variables.
#[derive(Debug)]
pub struct PlatformInfo {
    /// OS family: "darwin" or "linux" (maps to FLU_OS)
    pub os: String,
    /// Distro ID from /etc/os-release (maps to FLU_DISTRO)
    pub distro: String,
    /// Detected package manager name (maps to FLU_PKG_MGR)
    pub pkg_mgr: String,
    /// CPU architecture (maps to FLU_ARCH)
    pub arch: String,
    /// Running under WSL (maps to FLU_IS_WSL)
    pub is_wsl: bool,
    /// Running under Termux (maps to FLU_IS_TERMUX)
    pub is_termux: bool,
    /// Running as root (maps to FLU_IS_ROOT)
    pub is_root: bool,
}

/// Detect the current platform, producing identical results to flu.sh's
/// `flu_module_set_env()`.
pub fn detect() -> Result<PlatformInfo> {
    let os = detect_os();
    let distro = detect_distro();
    let pkg_mgr = detect_pkg_mgr();
    let arch = detect_arch();
    let is_wsl = detect_wsl();
    let is_termux = detect_termux();
    let is_root = detect_root();

    Ok(PlatformInfo {
        os,
        distro,
        pkg_mgr,
        arch,
        is_wsl,
        is_termux,
        is_root,
    })
}

fn detect_os() -> String {
    match std::env::consts::OS {
        "macos" => "darwin".to_string(),
        "linux" => "linux".to_string(),
        _ => "linux".to_string(), // default fallback
    }
}

fn detect_distro() -> String {
    if std::path::Path::new("/etc/os-release").exists() {
        let output = Command::new("sh")
            .arg("-c")
            .arg(". /etc/os-release 2>/dev/null && printf '%s' \"${ID:-linux}\"")
            .output();

        match output {
            Ok(out) => {
                let id = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if id.is_empty() {
                    "linux".to_string()
                } else {
                    id
                }
            }
            Err(_) => "linux".to_string(),
        }
    } else {
        "linux".to_string()
    }
}

fn detect_pkg_mgr() -> String {
    // Priority order matching _flu_detect_pkg_mgr exactly:
    // apt-get → apt, apk, dnf, pacman, zypper, brew → unknown
    let managers = [
        ("apt-get", "apt"),
        ("apk", "apk"),
        ("dnf", "dnf"),
        ("pacman", "pacman"),
        ("zypper", "zypper"),
        ("brew", "brew"),
    ];

    for (cmd, name) in &managers {
        let output = Command::new("sh")
            .arg("-c")
            .arg(format!("command -v {} >/dev/null 2>&1 && echo found", cmd))
            .output();
        if let Ok(out) = output {
            if String::from_utf8_lossy(&out.stdout).trim() == "found" {
                return name.to_string();
            }
        }
    }

    "unknown".to_string()
}

fn detect_arch() -> String {
    // Use std::env::consts::ARCH which maps to uname -m output
    std::env::consts::ARCH.to_string()
}

fn detect_wsl() -> bool {
    // Read /proc/version, check for "microsoft" (case-insensitive)
    // Return false if file doesn't exist (macOS)
    if let Ok(content) = std::fs::read_to_string("/proc/version") {
        content.to_lowercase().contains("microsoft")
    } else {
        false
    }
}

fn detect_termux() -> bool {
    // Check env var TERMUX_VERSION is set OR /data/data/com.termux directory exists
    if std::env::var("TERMUX_VERSION").is_ok() {
        return true;
    }
    std::path::Path::new("/data/data/com.termux").exists()
}

fn detect_root() -> bool {
    // Run `id -u` and check if result is "0"
    let output = Command::new("id").arg("-u").output();
    match output {
        Ok(out) => String::from_utf8_lossy(&out.stdout).trim() == "0",
        Err(_) => std::env::var("USER").unwrap_or_default() == "root",
    }
}

impl PlatformInfo {
    /// Format platform info for display, matching flu.sh's startup info format.
    pub fn display(&self) -> String {
        format!(
            "OS: {} | Distro: {} | Package Manager: {} | Architecture: {}",
            self.os, self.distro, self.pkg_mgr, self.arch
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_succeeds() {
        // detect() should succeed on the current platform without panicking
        let info = detect().expect("platform detection should succeed");
        assert!(!info.os.is_empty());
    }

    #[test]
    fn test_display_produces_output() {
        let info = detect().expect("platform detection should succeed");
        let display = info.display();
        assert!(!display.is_empty());
        assert!(display.contains("OS:"));
        assert!(display.contains("Distro:"));
        assert!(display.contains("Package Manager:"));
        assert!(display.contains("Architecture:"));
    }

    #[test]
    fn test_os_is_linux_or_darwin() {
        let info = detect().expect("platform detection should succeed");
        assert!(
            info.os == "linux" || info.os == "darwin",
            "OS should be linux or darwin, got: {}",
            info.os
        );
    }

    #[test]
    fn test_arch_is_nonempty() {
        let info = detect().expect("platform detection should succeed");
        assert!(!info.arch.is_empty(), "arch should not be empty");
    }
}
