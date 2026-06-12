use anyhow::Result;
use std::process::Command;

#[derive(Debug)]
pub struct PlatformInfo {
    pub os: String,
    pub distro: String,
    pub pkg_mgr: String,
    pub arch: String,
    pub is_wsl: bool,
    pub is_termux: bool,
    pub is_root: bool,
    pub disk_used: String,
    pub disk_total: String,
    pub disk_percent: u8,
    pub lan_ip: String,
    pub wan_ip: String,
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
    let (disk_used, disk_total, disk_percent) = detect_disk();
    let (lan_ip, wan_ip) = detect_ips();

    Ok(PlatformInfo {
        os,
        distro,
        pkg_mgr,
        arch,
        is_wsl,
        is_termux,
        is_root,
        disk_used,
        disk_total,
        disk_percent,
        lan_ip,
        wan_ip,
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
    let output = Command::new("id").arg("-u").output();
    match output {
        Ok(out) => String::from_utf8_lossy(&out.stdout).trim() == "0",
        Err(_) => std::env::var("USER").unwrap_or_default() == "root",
    }
}

fn detect_disk() -> (String, String, u8) {
    let output = Command::new("df")
        .arg("-h")
        .arg("/")
        .output();
    let stdout = match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
        Err(_) => return ("?".into(), "?".into(), 0),
    };
    let line = match stdout.lines().nth(1) {
        Some(l) => l,
        None => return ("?".into(), "?".into(), 0),
    };
    let fields: Vec<&str> = line.split_whitespace().collect();
    if fields.len() < 6 {
        return ("?".into(), "?".into(), 0);
    }
    let used = fields[2].to_string();
    let total = fields[1].to_string();
    let pct = fields[4].trim_end_matches('%').parse::<u8>().unwrap_or(0);
    (used, total, pct)
}

fn detect_ips() -> (String, String) {
    let lan = detect_lan_ip();
    let wan = detect_wan_ip();
    (lan, wan)
}

fn detect_lan_ip() -> String {
    #[cfg(unix)]
    {
        let output = Command::new("sh")
            .arg("-c")
            .arg("ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || hostname -I 2>/dev/null | awk '{print $1; exit}'")
            .output();
        if let Ok(o) = output {
            let ip = String::from_utf8_lossy(&o.stdout).trim().to_string();
            if !ip.is_empty() && ip.contains('.') {
                return ip;
            }
        }
    }
    #[cfg(windows)]
    {
        let output = Command::new("cmd")
            .args(["/C", "ipconfig"])
            .output();
        if let Ok(o) = output {
            let stdout = String::from_utf8_lossy(&o.stdout);
            for line in stdout.lines() {
                let line = line.trim();
                if line.starts_with("IPv4") {
                    if let Some(addr) = line.split(':').nth(1) {
                        let addr = addr.trim().split('%').next().unwrap_or("").trim();
                        if !addr.is_empty() {
                            return addr.to_string();
                        }
                    }
                }
            }
        }
    }
    "unavailable".to_string()
}

fn detect_wan_ip() -> String {
    let services = [
        "https://ifconfig.me",
        "https://icanhazip.com",
        "https://api.ipify.org",
    ];
    for url in &services {
        #[cfg(unix)]
        let output = Command::new("sh")
            .arg("-c")
            .arg(format!("curl -fsSL --connect-timeout 3 --max-time 5 {} 2>/dev/null || wget -qO- --timeout=5 {} 2>/dev/null", url, url))
            .output();
        #[cfg(windows)]
        let output = Command::new("cmd")
            .args(["/C", &format!("curl -fsSL --connect-timeout 3 --max-time 5 {} 2>nul", url)])
            .output();
        if let Ok(o) = output {
            let ip = String::from_utf8_lossy(&o.stdout).trim().to_string();
            if !ip.is_empty() && ip.contains('.') {
                return ip;
            }
        }
    }
    "unavailable".to_string()
}

impl PlatformInfo {
    pub fn display_lines(&self) -> Vec<String> {
        vec![
            format!(
                "OS: {} | Distro: {} | Package Manager: {}",
                self.os, self.distro, self.pkg_mgr
            ),
            format!(
                "Architecture: {} | Disk Space: {} / {} ({}%)",
                self.arch, self.disk_used, self.disk_total, self.disk_percent
            ),
            format!("IP: {} (LAN) | {} (WAN)", self.lan_ip, self.wan_ip),
            "github.com/C-Fu/dev-fu".to_string(),
        ]
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
        let lines = info.display_lines();
        assert_eq!(lines.len(), 4);
        assert!(lines[0].contains("OS:"));
        assert!(lines[0].contains("Distro:"));
        assert!(lines[0].contains("Package Manager:"));
        assert!(lines[1].contains("Architecture:"));
        assert!(lines[1].contains("Disk Space:"));
        assert!(lines[2].contains("IP:"));
        assert!(lines[3].contains("github.com"));
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
