use std::time::Duration;

use anyhow::{anyhow, Result};

use crate::fetch::{self, FetchConfig};
use crate::menu::MenuEntry;

const DEFAULT_REGISTRY_URL: &str =
    "https://raw.githubusercontent.com/C-Fu/dev-fu-registry/main/registry.json";

#[derive(Debug, Clone, serde::Deserialize)]
#[allow(dead_code)]
pub struct CommunityEntry {
    pub action_id: String,
    pub name: String,
    pub description: String,
    pub category: String,
    pub platforms: String,
    pub base_url: String,
    pub sha256: String,
}

pub fn fetch_registry() -> Result<Vec<CommunityEntry>> {
    let url =
        std::env::var("FLU_REGISTRY_URL").unwrap_or_else(|_| DEFAULT_REGISTRY_URL.to_string());

    let client = reqwest::blocking::Client::builder()
        .connect_timeout(Duration::from_secs(5))
        .timeout(Duration::from_secs(10))
        .build()?;

    let resp = client.get(&url).send()?;
    if !resp.status().is_success() {
        return Err(anyhow!("Registry fetch returned HTTP {}", resp.status()));
    }

    let body = resp.text()?;
    let entries: Vec<CommunityEntry> = serde_json::from_str(&body)?;
    Ok(entries)
}

pub fn lookup_entry<'a>(registry: &'a [CommunityEntry], action_id: &str) -> Option<&'a CommunityEntry> {
    registry.iter().find(|e| e.action_id == action_id)
}

pub fn fetch_community_module(entry: &CommunityEntry, config: &FetchConfig) -> Result<String> {
    let cache_key = format!("community_{}", entry.action_id);
    let cache_path = config.cache_dir.join(&cache_key);

    if let Some(content) = check_community_cache(&cache_path, config.cache_ttl) {
        eprintln!("[cached] community/{}", entry.action_id);
        return Ok(content);
    }

    let url = format!("{}{}.sh", entry.base_url, entry.action_id);
    eprintln!("Downloading community/{}.sh...", entry.action_id);

    let content = fetch_with_retry(&url, &entry.action_id)?;
    let size = content.len();
    eprintln!("  done ({} bytes)", size);

    let actual = fetch::compute_sha256(&content);
    if !actual.eq_ignore_ascii_case(&entry.sha256) {
        return Err(anyhow!(
            "Checksum mismatch for community/{} — possible tampering or corruption",
            entry.action_id
        ));
    }
    eprintln!("[verified] SHA256 checksum OK");

    if let Some(parent) = cache_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    let _ = std::fs::write(&cache_path, &content);

    Ok(content)
}

fn check_community_cache(path: &std::path::Path, ttl: Duration) -> Option<String> {
    let meta = std::fs::metadata(path).ok()?;
    if meta.len() == 0 {
        return None;
    }
    let mtime = meta.modified().ok()?;
    let now = std::time::SystemTime::now();
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

    let max_retries: u32 = 3;
    let mut last_err = None;
    for attempt in 1..=max_retries {
        match client.get(url).send() {
            Ok(resp) if resp.status().is_success() => {
                let body = resp.text()?;
                if body.is_empty() {
                    last_err = Some(anyhow!("Empty response for community/{}", action_id));
                    continue;
                }
                return Ok(body);
            }
            Ok(resp) => {
                last_err = Some(anyhow!(
                    "HTTP {} for community/{}",
                    resp.status(),
                    action_id
                ));
            }
            Err(e) => {
                last_err = Some(anyhow!(
                    "Fetch error for community/{}: {}",
                    action_id,
                    e
                ));
            }
        }
        if attempt < max_retries {
            eprintln!("  Retrying ({}/{})...", attempt + 1, max_retries);
            std::thread::sleep(Duration::from_secs(2));
        }
    }
    Err(last_err.unwrap_or_else(|| anyhow!("Failed to fetch community/{}", action_id)))
}

pub fn merge_community_entries(
    official: Vec<MenuEntry>,
    registry: &[CommunityEntry],
) -> Vec<MenuEntry> {
    if registry.is_empty() {
        return official;
    }

    let mut merged = official;
    for entry in registry {
        merged.push(MenuEntry {
            category: "Community Modules".to_string(),
            subcategory: entry.category.clone(),
            label: entry.name.clone(),
            action_id: format!("community/{}", entry.action_id),
        });
    }
    merged
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fetch_registry_invalid_url() {
        std::env::set_var("FLU_REGISTRY_URL", "http://127.0.0.1:1/nonexistent.json");
        let result = fetch_registry();
        assert!(result.is_err());
        std::env::remove_var("FLU_REGISTRY_URL");
    }

    #[test]
    fn test_lookup_entry_found() {
        let registry = vec![CommunityEntry {
            action_id: "install_foo".to_string(),
            name: "Install Foo".to_string(),
            description: "Installs foo".to_string(),
            category: "Tools".to_string(),
            platforms: "linux".to_string(),
            base_url: "https://example.com/modules/".to_string(),
            sha256: "abc123".to_string(),
        }];
        let entry = lookup_entry(&registry, "install_foo");
        assert!(entry.is_some());
        assert_eq!(entry.unwrap().name, "Install Foo");
    }

    #[test]
    fn test_lookup_entry_not_found() {
        let registry = vec![CommunityEntry {
            action_id: "install_foo".to_string(),
            name: "Install Foo".to_string(),
            description: "Installs foo".to_string(),
            category: "Tools".to_string(),
            platforms: "linux".to_string(),
            base_url: "https://example.com/modules/".to_string(),
            sha256: "abc123".to_string(),
        }];
        let entry = lookup_entry(&registry, "install_bar");
        assert!(entry.is_none());
    }

    #[test]
    fn test_merge_community_entries_appends() {
        let official = vec![MenuEntry {
            category: "Diagnostics".to_string(),
            subcategory: "System".to_string(),
            label: "Status Check".to_string(),
            action_id: "status_check".to_string(),
        }];
        let registry = vec![CommunityEntry {
            action_id: "install_foo".to_string(),
            name: "Install Foo".to_string(),
            description: "Installs foo".to_string(),
            category: "Tools".to_string(),
            platforms: "linux".to_string(),
            base_url: "https://example.com/modules/".to_string(),
            sha256: "abc123".to_string(),
        }];
        let merged = merge_community_entries(official, &registry);
        assert_eq!(merged.len(), 2);
        assert_eq!(merged[0].action_id, "status_check");
        assert_eq!(merged[1].action_id, "community/install_foo");
        assert_eq!(merged[1].category, "Community Modules");
        assert_eq!(merged[1].subcategory, "Tools");
    }

    #[test]
    fn test_merge_community_entries_empty_registry() {
        let official = vec![MenuEntry {
            category: "Diagnostics".to_string(),
            subcategory: "System".to_string(),
            label: "Status Check".to_string(),
            action_id: "status_check".to_string(),
        }];
        let merged = merge_community_entries(official.clone(), &[]);
        assert_eq!(merged.len(), 1);
        assert_eq!(merged[0].action_id, "status_check");
    }
}
