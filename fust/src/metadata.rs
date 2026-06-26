use anyhow::{anyhow, Result};

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct ModuleMetadata {
    pub name: String,
    pub params: String,
    pub platforms: Vec<String>,
    pub version: String,
    pub deps: String,
    pub timeout: u64,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ParamType {
    Radio,
    Text,
    YesNo,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct ParamDecl {
    pub index: usize,
    pub name: String,
    pub param_type: ParamType,
    pub choices: Vec<String>,
}

pub fn parse_metadata(content: &str) -> Result<ModuleMetadata> {
    let mut name = None;
    let mut params = String::new();
    let mut platforms = None;
    let mut version = None;
    let mut deps = String::new();
    let mut timeout: u64 = 300;

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || (!trimmed.starts_with('#')) {
            break;
        }
        let stripped = trimmed.strip_prefix('#').unwrap_or(trimmed).trim();
        if let Some(val) = stripped.strip_prefix("@name:") {
            name = Some(val.trim().to_string());
        } else if let Some(val) = stripped.strip_prefix("@params:") {
            params = val.trim().to_string();
        } else if let Some(val) = stripped.strip_prefix("@platforms:") {
            platforms = Some(
                val.trim()
                    .split(',')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect(),
            );
        } else if let Some(val) = stripped.strip_prefix("@version:") {
            version = Some(val.trim().to_string());
        } else if let Some(val) = stripped.strip_prefix("@deps:") {
            deps = val.trim().to_string();
        } else if let Some(val) = stripped.strip_prefix("@timeout:") {
            timeout = val.trim().parse::<u64>().unwrap_or(300);
        }
    }

    let name = name.ok_or_else(|| anyhow!("Missing required @name field in module header"))?;
    let platforms =
        platforms.ok_or_else(|| anyhow!("Missing required @platforms field in module header"))?;
    let version =
        version.ok_or_else(|| anyhow!("Missing required @version field in module header"))?;

    Ok(ModuleMetadata {
        name,
        params,
        platforms,
        version,
        deps,
        timeout,
    })
}

pub fn validate_platform(metadata: &ModuleMetadata, current_os: &str) -> Result<()> {
    if metadata
        .platforms
        .iter()
        .any(|p| p == current_os)
    {
        Ok(())
    } else {
        Err(anyhow!(
            "Module '{}' not available for this platform ({})",
            metadata.name,
            current_os
        ))
    }
}

pub fn parse_params(params_str: &str) -> Result<Vec<ParamDecl>> {
    if params_str.is_empty() {
        return Ok(vec![]);
    }

    let mut decls = Vec::new();
    for (idx, decl) in params_str.split(';').enumerate() {
        let decl = decl.trim();
        if decl.is_empty() {
            continue;
        }
        let eq_pos = decl
            .find('=')
            .ok_or_else(|| anyhow!("Invalid param format: missing '=' separator in '{}'", decl))?;
        let name = decl[..eq_pos].trim().to_string();
        let type_spec = &decl[eq_pos + 1..];

        let (param_type, choices) = if let Some(colon_pos) = type_spec.find(':') {
            let type_str = type_spec[..colon_pos].trim();
            let choices_str = &type_spec[colon_pos + 1..];
            let choices = choices_str
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect();
            (parse_param_type(type_str), choices)
        } else {
            let type_str = type_spec.trim();
            if type_str.is_empty() {
                (ParamType::Text, vec![])
            } else {
                (parse_param_type(type_str), vec![])
            }
        };

        decls.push(ParamDecl {
            index: idx,
            name,
            param_type,
            choices,
        });
    }
    Ok(decls)
}

fn parse_param_type(s: &str) -> ParamType {
    match s {
        "radio" => ParamType::Radio,
        "yesno" => ParamType::YesNo,
        _ => ParamType::Text,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_metadata_complete() {
        let content = "#!/usr/bin/env sh\n\
             # @name: Install Go\n\
             # @params: mode=radio:fast,slow\n\
             # @platforms: linux, darwin\n\
             # @version: 1.0.0\n\
             # @deps: curl\n\
             # @timeout: 600\n\
             #\n\
             set -eu\n";
        let meta = parse_metadata(content).unwrap();
        assert_eq!(meta.name, "Install Go");
        assert_eq!(meta.params, "mode=radio:fast,slow");
        assert_eq!(meta.platforms, vec!["linux", "darwin"]);
        assert_eq!(meta.version, "1.0.0");
        assert_eq!(meta.deps, "curl");
        assert_eq!(meta.timeout, 600);
    }

    #[test]
    fn test_parse_metadata_defaults() {
        let content = "#!/usr/bin/env sh\n\
             # @name: Test Module\n\
             # @params:\n\
             # @platforms: linux\n\
             # @version: 3.0.0-alpha.13\n\
             #\n\
             echo hello\n";
        let meta = parse_metadata(content).unwrap();
        assert_eq!(meta.name, "Test Module");
        assert_eq!(meta.params, "");
        assert_eq!(meta.deps, "");
        assert_eq!(meta.timeout, 300);
    }

    #[test]
    fn test_parse_metadata_missing_name() {
        let content = "# @platforms: linux\n# @version: 1.0.0\n";
        let result = parse_metadata(content);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("@name"));
    }

    #[test]
    fn test_parse_metadata_missing_platforms() {
        let content = "# @name: Test\n# @version: 1.0.0\n";
        let result = parse_metadata(content);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("@platforms"));
    }

    #[test]
    fn test_parse_metadata_terminates_at_blank_line() {
        let content = "# @name: Test\n# @platforms: linux\n# @version: 1.0.0\n\n# @name: Should be ignored\n";
        let meta = parse_metadata(content).unwrap();
        assert_eq!(meta.name, "Test");
    }

    #[test]
    fn test_parse_metadata_terminates_at_non_comment() {
        let content = "# @name: Test\n# @platforms: linux\n# @version: 1.0.0\nset -eu\n# @name: Ignored\n";
        let meta = parse_metadata(content).unwrap();
        assert_eq!(meta.name, "Test");
    }

    #[test]
    fn test_validate_platform_match() {
        let meta = ModuleMetadata {
            name: "Test".to_string(),
            params: String::new(),
            platforms: vec!["linux".to_string(), "darwin".to_string()],
            version: "1.0.0".to_string(),
            deps: String::new(),
            timeout: 300,
        };
        assert!(validate_platform(&meta, "linux").is_ok());
    }

    #[test]
    fn test_validate_platform_mismatch() {
        let meta = ModuleMetadata {
            name: "Test".to_string(),
            params: String::new(),
            platforms: vec!["linux".to_string()],
            version: "1.0.0".to_string(),
            deps: String::new(),
            timeout: 300,
        };
        assert!(validate_platform(&meta, "darwin").is_err());
    }

    #[test]
    fn test_parse_params_empty() {
        let result = parse_params("").unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn test_parse_params_radio() {
        let decls = parse_params("mode=radio:fast,slow").unwrap();
        assert_eq!(decls.len(), 1);
        assert_eq!(decls[0].name, "mode");
        assert_eq!(decls[0].param_type, ParamType::Radio);
        assert_eq!(decls[0].choices, vec!["fast", "slow"]);
    }

    #[test]
    fn test_parse_params_text() {
        let decls = parse_params("name=text").unwrap();
        assert_eq!(decls.len(), 1);
        assert_eq!(decls[0].name, "name");
        assert_eq!(decls[0].param_type, ParamType::Text);
        assert!(decls[0].choices.is_empty());
    }

    #[test]
    fn test_parse_params_yesno() {
        let decls = parse_params("confirm=yesno").unwrap();
        assert_eq!(decls.len(), 1);
        assert_eq!(decls[0].name, "confirm");
        assert_eq!(decls[0].param_type, ParamType::YesNo);
    }

    #[test]
    fn test_parse_params_multiple() {
        let decls = parse_params("a=radio:x,y;b=text").unwrap();
        assert_eq!(decls.len(), 2);
        assert_eq!(decls[0].name, "a");
        assert_eq!(decls[0].param_type, ParamType::Radio);
        assert_eq!(decls[1].name, "b");
        assert_eq!(decls[1].param_type, ParamType::Text);
    }

    #[test]
    fn test_parse_params_missing_separator() {
        let result = parse_params("invalid_no_equals");
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("missing '='"));
    }

    #[test]
    fn test_parse_real_module_header() {
        let content = "#!/usr/bin/env sh\n\
             # @name: Install Go\n\
             # @params:\n\
             # @platforms: linux, darwin\n\
             # @version: 1.0.0\n\
             # @deps:\n\
             # @timeout: 300\n\
             #\n\
             set -eu\n";
        let meta = parse_metadata(content).unwrap();
        assert_eq!(meta.name, "Install Go");
        assert_eq!(meta.platforms, vec!["linux", "darwin"]);
        assert_eq!(meta.version, "1.0.0");
        assert_eq!(meta.timeout, 300);
    }
}
