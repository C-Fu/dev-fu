use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, Instant};

use anyhow::{anyhow, Result};

use crate::fetch;
use crate::metadata::{self, ParamType};
use crate::platform::PlatformInfo;

pub fn execute_module(action_id: &str, platform: &PlatformInfo) -> Result<i32> {
    let config = fetch::FetchConfig::from_env();

    let script_content = fetch::fetch_module(&config, action_id)?;

    let meta = metadata::parse_metadata(&script_content)?;

    metadata::validate_platform(&meta, &platform.os)
        .map_err(|e| anyhow!("Platform check failed: {}", e))?;

    let param_args = if !meta.params.is_empty() {
        Some(collect_params(&meta.params)?)
    } else {
        None
    };

    let script_path = write_temp_script(&script_content)?;

    let env_vars = build_env_vars(platform);

    let (code, duration_secs) = execute_with_timeout(
        meta.timeout,
        &script_path,
        param_args.as_deref(),
        &env_vars,
    )?;

    let result_str = if code == 0 { "success" } else { "fail" };
    log_execution(action_id, result_str, &meta.version, duration_secs);

    let _ = std::fs::remove_file(&script_path);

    if code == 0 {
        eprintln!("  ✓ {} — Complete", meta.name);
    } else {
        eprintln!("  ✗ {} — Failed (exit {})", meta.name, code);
    }

    Ok(code)
}

fn write_temp_script(content: &str) -> Result<PathBuf> {
    let tmp_dir = std::env::var("TMPDIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/tmp"));
    let pid = std::process::id();
    let path = tmp_dir.join(format!("flu_module_{}.sh", pid));
    let mut file = std::fs::File::create(&path)?;
    file.write_all(content.as_bytes())?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = std::fs::metadata(&path)?.permissions();
        perms.set_mode(0o755);
        std::fs::set_permissions(&path, perms)?;
    }
    Ok(path)
}

fn build_env_vars(platform: &PlatformInfo) -> Vec<(String, String)> {
    vec![
        ("FLU_OS".to_string(), platform.os.clone()),
        ("FLU_DISTRO".to_string(), platform.distro.clone()),
        ("FLU_PKG_MGR".to_string(), platform.pkg_mgr.clone()),
        ("FLU_ARCH".to_string(), platform.arch.clone()),
        (
            "FLU_IS_WSL".to_string(),
            if platform.is_wsl { "1" } else { "0" }.to_string(),
        ),
        (
            "FLU_IS_TERMUX".to_string(),
            if platform.is_termux { "1" } else { "0" }.to_string(),
        ),
        (
            "FLU_IS_ROOT".to_string(),
            if platform.is_root { "1" } else { "0" }.to_string(),
        ),
    ]
}

fn execute_with_timeout(
    timeout_secs: u64,
    script_path: &Path,
    args: Option<&[(String, String)]>,
    env_vars: &[(String, String)],
) -> Result<(i32, u64)> {
    let start = Instant::now();
    let timeout = Duration::from_secs(timeout_secs);

    let mut cmd = Command::new("sh");
    cmd.arg(script_path);
    cmd.arg("--");

    if let Some(param_args) = args {
        for (key, value) in param_args {
            cmd.arg(key);
            cmd.arg(value);
        }
    }

    for (k, v) in env_vars {
        cmd.env(k, v);
    }

    let mut child = cmd.spawn()?;

    loop {
        match child.try_wait()? {
            Some(status) => {
                let duration = start.elapsed().as_secs();
                let code = status.code().unwrap_or(1);
                let code = if code == 137 { 124 } else { code };
                return Ok((code, duration));
            }
            None => {
                if start.elapsed() > timeout {
                    let _ = child.kill();
                    let _ = child.wait();
                    let duration = start.elapsed().as_secs();
                    eprintln!("  ✗ Timed out after {}s", timeout_secs);
                    return Ok((124, duration));
                }
                std::thread::sleep(Duration::from_millis(100));
            }
        }
    }
}

pub fn collect_params(params_str: &str) -> Result<Vec<(String, String)>> {
    let decls = metadata::parse_params(params_str)?;
    let mut collected = Vec::new();

    for decl in &decls {
        let value = match decl.param_type {
            ParamType::Radio => collect_radio_param(&decl.name, &decl.choices)?,
            ParamType::Text => collect_text_param(&decl.name)?,
            ParamType::YesNo => collect_yesno_param(&decl.name)?,
        };
        collected.push((format!("--{}", decl.name), value));
    }

    Ok(collected)
}

fn collect_radio_param(name: &str, choices: &[String]) -> Result<String> {
    if choices.is_empty() {
        return Ok(String::new());
    }

    let mut guard = crate::tui::terminal::TerminalGuard::init()?;
    let theme = crate::tui::theme::Theme::dark();

    let items: Vec<&str> = choices.iter().map(|s| s.as_str()).collect();
    let result = crate::tui::widgets::radio::radio(
        guard.terminal(),
        &theme,
        name,
        "Select one option",
        &items,
        Some(0),
    )?;
    drop(guard);

    match result {
        Some(idx) => Ok(choices[idx].clone()),
        None => Err(anyhow!("Parameter collection cancelled")),
    }
}

fn collect_text_param(name: &str) -> Result<String> {
    let mut guard = crate::tui::terminal::TerminalGuard::init()?;
    let theme = crate::tui::theme::Theme::dark();

    let result = crate::tui::widgets::text_input::text_input(
        guard.terminal(),
        &theme,
        name,
        &format!("Enter {}:", name),
        "",
    );
    drop(guard);

    match result {
        Ok(value) => Ok(value),
        Err(_) => Err(anyhow!("Parameter collection cancelled")),
    }
}

fn collect_yesno_param(name: &str) -> Result<String> {
    let mut guard = crate::tui::terminal::TerminalGuard::init()?;
    let theme = crate::tui::theme::Theme::dark();

    let result = crate::tui::widgets::yesno::yesno(
        guard.terminal(),
        &theme,
        name,
        &format!("{}?", name),
        false,
    );
    drop(guard);

    match result {
        Ok(true) => Ok("yes".to_string()),
        Ok(false) => Ok("no".to_string()),
        Err(_) => Err(anyhow!("Parameter collection cancelled")),
    }
}

pub fn classify_operation(action_id: &str) -> &'static str {
    if action_id.starts_with("install_") {
        "install"
    } else if action_id.starts_with("remove_") {
        "remove"
    } else if action_id.starts_with("create_") {
        "create"
    } else if action_id.starts_with("configure_") {
        "configure"
    } else if action_id.starts_with("set_") {
        "set"
    } else if action_id.starts_with("status_") {
        "status"
    } else if action_id.starts_with("upgrade_") {
        "upgrade"
    } else {
        "other"
    }
}

pub fn log_execution(action_id: &str, result: &str, version: &str, duration_secs: u64) {
    let data_dir = std::env::var("FLU_DATA_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            std::env::var("XDG_DATA_HOME")
                .map(|p| PathBuf::from(p).join("flu.sh"))
                .unwrap_or_else(|_| {
                    PathBuf::from(
                        std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string()),
                    )
                    .join(".local")
                    .join("share")
                    .join("flu.sh")
                })
        });

    let _ = std::fs::create_dir_all(&data_dir);
    let log_path = data_dir.join("execution.log");

    let timestamp = Command::new("date")
        .arg("+%Y-%m-%dT%H:%M:%S%z")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "-".to_string());

    let operation = classify_operation(action_id);

    let write_header = !log_path.exists()
        || std::fs::metadata(&log_path).map(|m| m.len() == 0).unwrap_or(true);

    let mut file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .ok();

    if let Some(ref mut file) = file {
        if write_header {
            let _ = writeln!(file, "timestamp\taction_id\toperation\tresult\tversion\tduration_seconds");
        }
        let _ = writeln!(
            file,
            "{}\t{}\t{}\t{}\t{}\t{}",
            timestamp, action_id, operation, result, version, duration_secs
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classify_operation_install() {
        assert_eq!(classify_operation("install_go"), "install");
    }

    #[test]
    fn test_classify_operation_remove() {
        assert_eq!(classify_operation("remove_go"), "remove");
    }

    #[test]
    fn test_classify_operation_create() {
        assert_eq!(classify_operation("create_fancy_prompt"), "create");
    }

    #[test]
    fn test_classify_operation_configure() {
        assert_eq!(classify_operation("configure_mouse_disable"), "configure");
    }

    #[test]
    fn test_classify_operation_set() {
        assert_eq!(classify_operation("set_github_token"), "set");
    }

    #[test]
    fn test_classify_operation_status() {
        assert_eq!(classify_operation("status_check"), "status");
    }

    #[test]
    fn test_classify_operation_upgrade() {
        assert_eq!(classify_operation("upgrade_all"), "upgrade");
    }

    #[test]
    fn test_classify_operation_other() {
        assert_eq!(classify_operation("unknown_action"), "other");
    }

    #[test]
    fn test_build_env_vars() {
        let platform = PlatformInfo {
            os: "linux".to_string(),
            distro: "ubuntu".to_string(),
            pkg_mgr: "apt".to_string(),
            arch: "x86_64".to_string(),
            is_wsl: false,
            is_termux: false,
            is_root: true,
            disk_used: "50G".to_string(),
            disk_total: "100G".to_string(),
            disk_percent: 50,
            lan_ip: "192.168.1.1".to_string(),
            wan_ip: "1.2.3.4".to_string(),
        };
        let vars = build_env_vars(&platform);
        assert_eq!(vars.len(), 7);
        assert_eq!(vars[0], ("FLU_OS".to_string(), "linux".to_string()));
        assert_eq!(vars[1], ("FLU_DISTRO".to_string(), "ubuntu".to_string()));
        assert_eq!(vars[2], ("FLU_PKG_MGR".to_string(), "apt".to_string()));
        assert_eq!(vars[3], ("FLU_ARCH".to_string(), "x86_64".to_string()));
        assert_eq!(vars[4], ("FLU_IS_WSL".to_string(), "0".to_string()));
        assert_eq!(vars[5], ("FLU_IS_TERMUX".to_string(), "0".to_string()));
        assert_eq!(vars[6], ("FLU_IS_ROOT".to_string(), "1".to_string()));
    }

    #[test]
    fn test_log_execution_creates_file() {
        let dir = std::env::temp_dir().join("fust_test_log");
        let _ = std::fs::remove_dir_all(&dir);
        std::env::set_var("FLU_DATA_DIR", &dir);

        log_execution("install_go", "success", "1.0.0", 15);

        let log_path = dir.join("execution.log");
        assert!(log_path.exists());

        let content = std::fs::read_to_string(&log_path).unwrap();
        assert!(content.contains("timestamp\taction_id\t"));
        assert!(content.contains("install_go\tinstall\tsuccess\t1.0.0\t15"));

        std::env::remove_var("FLU_DATA_DIR");
        let _ = std::fs::remove_dir_all(&dir);
    }
}
