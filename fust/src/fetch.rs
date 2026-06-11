use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

use anyhow::{anyhow, Result};
use sha2::{Digest, Sha256};

const DEFAULT_BASE_URL: &str = "https://raw.githubusercontent.com/C-Fu/dev-fu/flu.sh/modules/";
const DEFAULT_CACHE_TTL: u64 = 86400;
const MAX_RETRIES: u32 = 3;

pub struct FetchConfig {
    pub base_url: String,
    pub cache_dir: PathBuf,
    pub cache_ttl: Duration,
}

impl FetchConfig {
    pub fn from_env() -> Self {
        let base_url = std::env::var("FLU_MODULES_BASE_URL")
            .unwrap_or_else(|_| DEFAULT_BASE_URL.to_string());

        let cache_dir = std::env::var("FLU_CACHE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                std::env::var("XDG_CACHE_HOME")
                    .map(|p| PathBuf::from(p).join("flu.sh"))
                    .unwrap_or_else(|_| {
                        PathBuf::from(
                            std::env::var("HOME")
                                .unwrap_or_else(|_| "/tmp".to_string()),
                        )
                        .join(".cache")
                        .join("flu.sh")
                    })
            });

        let cache_ttl = Duration::from_secs(
            std::env::var("FLU_CACHE_TTL")
                .ok()
                .and_then(|s| s.parse::<u64>().ok())
                .unwrap_or(DEFAULT_CACHE_TTL),
        );

        Self {
            base_url,
            cache_dir,
            cache_ttl,
        }
    }
}

pub fn resolve_url(config: &FetchConfig, action_id: &str) -> String {
    format!("{}{}.sh", config.base_url, action_id)
}

pub fn fetch_manifest(config: &FetchConfig) -> Option<String> {
    let url = format!("{}MANIFEST.sha256", config.base_url);
    let client = reqwest::blocking::Client::builder()
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(10))
        .build()
        .ok()?;

    match client.get(&url).send() {
        Ok(resp) if resp.status().is_success() => resp.text().ok(),
        Ok(resp) => {
            eprintln!("[WARN] Manifest fetch returned status {}", resp.status());
            None
        }
        Err(e) => {
            eprintln!("[WARN] Cannot fetch manifest: {}", e);
            None
        }
    }
}

pub fn fetch_module(config: &FetchConfig, action_id: &str) -> Result<String> {
    if let Some(module_id) = action_id.strip_prefix("community/") {
        let reg = crate::registry::fetch_registry()?;
        let entry = crate::registry::lookup_entry(&reg, module_id)
            .ok_or_else(|| anyhow!("Community module not found: {}", module_id))?;
        return crate::registry::fetch_community_module(entry, config);
    }

    let cache_path = config.cache_dir.join(action_id);
    if let Some(content) = check_cache(&cache_path, config.cache_ttl) {
        eprintln!("[cached] {}", action_id);
        return Ok(content);
    }

    let url = resolve_url(config, action_id);
    eprintln!("Downloading {}.sh...", action_id);

    let content = fetch_with_retry(&url, action_id)?;
    let size = content.len();
    eprintln!("  done ({} bytes)", size);

    verify_checksum(config, action_id, &content)?;

    store_cache(&cache_path, &content)?;

    Ok(content)
}

fn check_cache(path: &Path, ttl: Duration) -> Option<String> {
    let meta = std::fs::metadata(path).ok()?;
    if meta.len() == 0 {
        return None;
    }
    let mtime = meta.modified().ok()?;
    let now = SystemTime::now();
    let age = now.duration_since(mtime).ok()?;
    if age < ttl {
        std::fs::read_to_string(path).ok()
    } else {
        None
    }
}

fn fetch_with_retry(url: &str, action_id: &str) -> Result<String> {
    let client = reqwest::blocking::Client::builder()
        .connect_timeout(Duration::from_secs(10))
        .timeout(Duration::from_secs(30))
        .build()?;

    let mut last_err = None;
    for attempt in 1..=MAX_RETRIES {
        match client.get(url).send() {
            Ok(resp) if resp.status().is_success() => {
                let body = resp.text()?;
                if body.is_empty() {
                    last_err = Some(anyhow!("Empty response for {}", action_id));
                    continue;
                }
                return Ok(body);
            }
            Ok(resp) => {
                last_err = Some(anyhow!(
                    "HTTP {} for {}",
                    resp.status(),
                    action_id
                ));
            }
            Err(e) => {
                last_err = Some(anyhow!("Fetch error for {}: {}", action_id, e));
            }
        }
        if attempt < MAX_RETRIES {
            eprintln!("  Retrying ({}/{})...", attempt + 1, MAX_RETRIES);
            std::thread::sleep(Duration::from_secs(2));
        }
    }
    Err(last_err.unwrap_or_else(|| anyhow!("Failed to fetch {}", action_id)))
}

fn verify_checksum(config: &FetchConfig, action_id: &str, content: &str) -> Result<()> {
    let manifest = match fetch_manifest(config) {
        Some(m) => m,
        None => {
            eprintln!("[WARN] Cannot verify checksum — manifest unavailable");
            return Ok(());
        }
    };

    let filename = format!("{}.sh", action_id);
    let expected = parse_manifest_hash(&manifest, &filename);

    match expected {
        Some(expected_hex) => {
            let actual = compute_sha256(content);
            if actual.eq_ignore_ascii_case(&expected_hex) {
                eprintln!("[verified] SHA256 checksum OK");
                Ok(())
            } else {
                Err(anyhow!(
                    "Checksum mismatch for {} — possible tampering or corruption",
                    filename
                ))
            }
        }
        None => {
            eprintln!("[WARN] {} not found in manifest", filename);
            Ok(())
        }
    }
}

pub fn parse_manifest_hash(manifest: &str, filename: &str) -> Option<String> {
    for line in manifest.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some(idx) = line.find("  ") {
            let (hash, rest) = line.split_at(idx);
            let rest = rest.trim();
            if rest == filename {
                return Some(hash.to_string());
            }
        }
    }
    None
}

pub fn compute_sha256(content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    hex::encode(hasher.finalize())
}

fn store_cache(path: &Path, content: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let tmp_path = path.with_extension("tmp_cache");
    if std::fs::write(&tmp_path, content).is_ok() {
        if std::fs::rename(&tmp_path, path).is_ok() {
            return Ok(());
        }
        let _ = std::fs::remove_file(&tmp_path);
    }
    std::fs::write(path, content)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_resolve_url() {
        let config = FetchConfig {
            base_url: "https://example.com/modules/".to_string(),
            cache_dir: PathBuf::from("/tmp/test"),
            cache_ttl: Duration::from_secs(86400),
        };
        assert_eq!(
            resolve_url(&config, "install_go"),
            "https://example.com/modules/install_go.sh"
        );
    }

    #[test]
    fn test_fetch_config_from_env_defaults() {
        std::env::remove_var("FLU_MODULES_BASE_URL");
        std::env::remove_var("FLU_CACHE_DIR");
        std::env::remove_var("FLU_CACHE_TTL");
        std::env::remove_var("XDG_CACHE_HOME");
        let config = FetchConfig::from_env();
        assert_eq!(config.base_url, DEFAULT_BASE_URL);
        assert!(config.cache_dir.to_string_lossy().ends_with("flu.sh"));
        assert_eq!(config.cache_ttl, Duration::from_secs(DEFAULT_CACHE_TTL));
    }

    #[test]
    fn test_fetch_config_from_env_overrides() {
        std::env::set_var("FLU_MODULES_BASE_URL", "https://custom.example.com/");
        std::env::set_var("FLU_CACHE_TTL", "3600");
        let config = FetchConfig::from_env();
        assert_eq!(config.base_url, "https://custom.example.com/");
        assert_eq!(config.cache_ttl, Duration::from_secs(3600));
        std::env::remove_var("FLU_MODULES_BASE_URL");
        std::env::remove_var("FLU_CACHE_TTL");
    }

    #[test]
    fn test_compute_sha256_correct() {
        let content = "hello world\n";
        let hash = compute_sha256(content);
        assert_eq!(
            hash,
            "a948904f2f0f479b8f8197694b30184b0d2ed1c1cd2a1ec0fb85d299a192a447"
        );
    }

    #[test]
    fn test_compute_sha256_mismatch() {
        let content = "hello world\n";
        let hash = compute_sha256(content);
        assert_ne!(hash, "0000000000000000000000000000000000000000000000000000000000000000");
    }

    #[test]
    fn test_parse_manifest_line() {
        let manifest = "95bc63c1069da7795610ca2a7593501bb4bb1f8fa56ec5c833a1ef77f8fcc6f0  install_go.sh\n";
        let result = parse_manifest_hash(manifest, "install_go.sh");
        assert_eq!(
            result,
            Some("95bc63c1069da7795610ca2a7593501bb4bb1f8fa56ec5c833a1ef77f8fcc6f0".to_string())
        );
    }

    #[test]
    fn test_parse_manifest_not_found() {
        let manifest = "95bc63c1069da7795610ca2a7593501bb4bb1f8fa56ec5c833a1ef77f8fcc6f0  install_go.sh\n";
        let result = parse_manifest_hash(manifest, "nonexistent.sh");
        assert_eq!(result, None);
    }

    #[test]
    fn test_cache_hit_returns_cached_content() {
        let dir = std::env::temp_dir().join("fust_test_cache_hit");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test_module");
        std::fs::write(&path, "cached content").unwrap();

        let content = check_cache(&path, Duration::from_secs(3600));
        assert_eq!(content, Some("cached content".to_string()));

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_cache_expired_triggers_refetch() {
        let dir = std::env::temp_dir().join("fust_test_cache_expired");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("test_module");
        std::fs::write(&path, "old content").unwrap();

        let content = check_cache(&path, Duration::from_secs(0));
        assert!(content.is_none());

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_community_modules_delegate_to_registry() {
        std::env::set_var("FLU_REGISTRY_URL", "http://127.0.0.1:1/nonexistent.json");
        let config = FetchConfig::from_env();
        let result = fetch_module(&config, "community/some_module");
        assert!(result.is_err());
        std::env::remove_var("FLU_REGISTRY_URL");
    }

    #[test]
    fn test_parse_manifest_skips_comments() {
        let manifest = "# comment\n\nrealhash  file.sh\n";
        let result = parse_manifest_hash(manifest, "file.sh");
        assert_eq!(result, Some("realhash".to_string()));
    }
}
