#[allow(unused_imports)]
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::Path;

fn main() {
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest = Path::new(&out_dir).join("module_info_generated.rs");

    let modules_dir = Path::new("../flu-sh/modules");
    let mut entries: Vec<(String, String, String, String, String)> = Vec::new();

    if let Ok(files) = fs::read_dir(modules_dir) {
        let mut sh_files: Vec<_> = files
            .filter_map(|e| e.ok())
            .filter(|e| e.path().extension().is_some_and(|ext| ext == "sh"))
            .collect();
        sh_files.sort_by_key(|e| e.file_name());

        for file in &sh_files {
            let action_id = file.path().file_stem().unwrap().to_string_lossy().to_string();
            let content = fs::read_to_string(file.path()).unwrap_or_default();

            let mut name = String::new();
            let mut platforms = String::new();
            let mut version = String::new();
            let mut description = String::new();

            for line in content.lines() {
                let trimmed = line.trim();
                if !trimmed.starts_with('#') && !trimmed.is_empty() {
                    break;
                }
                let stripped = trimmed.strip_prefix('#').unwrap_or(trimmed).trim();
                if let Some(val) = stripped.strip_prefix("@name:") {
                    name = val.trim().to_string();
                } else if let Some(val) = stripped.strip_prefix("@platforms:") {
                    platforms = val.trim().to_string();
                } else if let Some(val) = stripped.strip_prefix("@version:") {
                    version = val.trim().to_string();
                } else if !stripped.is_empty()
                    && !stripped.starts_with('@')
                    && !stripped.starts_with("!")
                    && !name.is_empty()
                {
                    if !description.is_empty() {
                        description.push(' ');
                    }
                    description.push_str(stripped);
                }
            }

            if name.is_empty() {
                name = action_id.clone();
            }

            entries.push((action_id, name, platforms, version, description));
        }
    }

    let mut output = String::new();
    output.push_str("use std::sync::LazyLock;\n\n");
    output.push_str("#[derive(Debug, Clone)]\n#[allow(dead_code)]\npub struct ModuleInfo {\n");
    output.push_str("    pub name: &'static str,\n");
    output.push_str("    pub platforms: &'static str,\n");
    output.push_str("    pub version: &'static str,\n");
    output.push_str("    pub description: &'static str,\n");
    output.push_str("}\n\n");
    output.push_str("pub static MODULE_INFO: LazyLock<std::collections::HashMap<&'static str, ModuleInfo>> = LazyLock::new(|| {\n");
    output.push_str("    let mut m = std::collections::HashMap::new();\n");

    for (action_id, name, platforms, version, description) in &entries {
        let desc_escaped = description.replace('\\', "\\\\").replace('"', "\\\"");
        output.push_str(&format!(
            "    m.insert(\"{}\", ModuleInfo {{ name: \"{}\", platforms: \"{}\", version: \"{}\", description: \"{}\" }});\n",
            action_id, name, platforms, version, desc_escaped
        ));
    }

    output.push_str("    m\n});\n");

    fs::write(&dest, output).unwrap();
}