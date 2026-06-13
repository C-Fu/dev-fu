mod cli;
mod error;
mod execute;
mod fetch;
mod logo;
mod menu;
mod metadata;
mod module_info;
mod navigation;
mod platform;
mod registry;
mod tui;

use clap::Parser;

fn batch_run(action_ids: &[String], platform: &platform::PlatformInfo) -> anyhow::Result<i32> {
    let entries = menu::parse_menu_db();
    let valid_ids: Vec<&str> = entries.iter().map(|e| e.action_id.as_str()).collect();
    let mut ok_count = 0usize;
    let mut fail_count = 0u32;

    for action_id in action_ids {
        if !action_id.starts_with("community/") && !valid_ids.contains(&action_id.as_str()) {
            eprintln!("✗ {} — Unknown action ID", action_id);
            fail_count += 1;
            continue;
        }

        eprintln!("▶ {}", action_id);

        match execute::execute_module(action_id, platform) {
            Ok(0) => {
                ok_count += 1;
            }
            Ok(code) => {
                let category = error::classify_exit_code(code);
                eprintln!("✗ {} — {}", action_id, error::format_hint(&category));
                fail_count += 1;
            }
            Err(e) => {
                eprintln!("✗ {} — Error: {}", action_id, e);
                fail_count += 1;
            }
        }
    }

    eprintln!();
    if fail_count == 0 {
        eprintln!("{} succeeded, 0 failed", ok_count);
    } else {
        eprintln!("{} succeeded, {} failed", ok_count, fail_count);
    }

    Ok(if fail_count > 0 { 1 } else { 0 })
}

fn main() -> anyhow::Result<()> {
    let args = cli::Cli::parse();

    // Detect platform (always, matching flu.sh behavior)
    let platform = platform::detect()?;

    if args.list {
        let entries = menu::parse_menu_db();
        let merged = match registry::fetch_registry() {
            Ok(reg) => registry::merge_community_entries(entries, &reg),
            Err(_) => entries,
        };
        if args.json {
            menu::print_json(&merged);
        } else {
            menu::print_table(&merged);
        }
        return Ok(());
    }

    if args.install.is_some() || args.remove.is_some() {
        let action_ids: Vec<String> = if let Some(ref ids) = args.install {
            ids.split(',').map(|s| s.trim().to_string()).collect()
        } else if let Some(ref ids) = args.remove {
            ids.split(',')
                .map(|s| format!("remove_{}", s.trim()))
                .collect()
        } else {
            vec![]
        };
        if action_ids.is_empty() {
            eprintln!("Error: no action IDs provided");
            std::process::exit(2);
        }
        let exit_code = batch_run(&action_ids, &platform)?;
        std::process::exit(exit_code);
    }

    // Demo flags (per D-16) — standalone widget testing
    if args.demo_select
        || args.demo_checklist
        || args.demo_radio
        || args.demo_yesno
        || args.demo_text_input
        || args.demo_menu
    {
        let mut guard = tui::terminal::TerminalGuard::init()?;
        let theme = tui::theme::Theme::dark();

        if args.demo_select {
            let items = vec![
                "Install Docker",
                "Install Go",
                "Install Rust",
                "Install Python",
                "Install Node.js",
            ];
            let result = tui::widgets::select::select(
                guard.terminal(),
                &theme,
                "Select an action",
                "Choose one option",
                &items,
            )?;
            drop(guard);
            match result {
                Some(idx) => println!("Selected: {} ({})", items[idx], idx),
                None => println!("Cancelled"),
            }
        } else if args.demo_checklist {
            let items = vec!["Docker", "Go", "Rust", "Python", "Node.js"];
            let result = tui::widgets::checklist::checklist(
                guard.terminal(),
                &theme,
                "Select tools to install",
                "Space to toggle, Enter to confirm",
                &items,
                &[0, 2], // pre-check Docker and Rust
            )?;
            drop(guard);
            if result.is_empty() {
                println!("Cancelled");
            } else {
                let names: Vec<_> = result.iter().map(|&i| items[i]).collect();
                println!("Selected: {:?}", names);
            }
        } else if args.demo_radio {
            let items = vec!["Dark theme", "Light theme", "Monochrome"];
            let result = tui::widgets::radio::radio(
                guard.terminal(),
                &theme,
                "Choose theme",
                "Select one option",
                &items,
                Some(0), // default to first
            )?;
            drop(guard);
            match result {
                Some(idx) => println!("Selected: {} ({})", items[idx], idx),
                None => println!("Cancelled"),
            }
        } else if args.demo_yesno {
            let result = tui::widgets::yesno::yesno(
                guard.terminal(),
                &theme,
                "Confirm",
                "Proceed with installation?",
                false,
            );
            drop(guard);
            match result {
                Ok(true) => println!("Answer: yes"),
                Ok(false) => println!("Answer: no"),
                Err(_) => println!("Cancelled"),
            }
        } else if args.demo_text_input {
            let result = tui::widgets::text_input::text_input(
                guard.terminal(),
                &theme,
                "Configuration",
                "Enter your name:",
                "developer",
            );
            drop(guard);
            match result {
                Ok(value) => println!("Input: {}", value),
                Err(_) => println!("Cancelled"),
            }
        } else if args.demo_menu {
            logo::show_splash(guard.terminal(), &theme, &platform)?;
            let entries = menu::parse_menu_db();
            let entries = match registry::fetch_registry() {
                Ok(reg) => registry::merge_community_entries(entries, &reg),
                Err(_) => entries,
            };
            let tree = navigation::build_navigation_tree(&entries);
            let result = tui::widgets::menu::menu(guard.terminal(), &theme, &tree)?;
            drop(guard);
            match result {
                Some(action_ids) => {
                    for action_id in &action_ids {
                        eprintln!("▶ {}", action_id);
                        match execute::execute_module(action_id, &platform) {
                            Ok(0) => {}
                            Ok(code) => {
                                let cat = error::classify_exit_code(code);
                                eprintln!("✗ {} — {}", action_id, error::format_hint(&cat));
                            }
                            Err(e) => eprintln!("✗ {} — Error: {}", action_id, e),
                        }
                    }
                }
                None => println!("Cancelled"),
            }
        }
        return Ok(());
    }

    // No args → TUI menu mode
    let mut guard = tui::terminal::TerminalGuard::init()?;
    let theme = tui::theme::Theme::dark();

    logo::show_splash(guard.terminal(), &theme, &platform)?;

    let entries = menu::parse_menu_db();
    let entries = match registry::fetch_registry() {
        Ok(reg) => registry::merge_community_entries(entries, &reg),
        Err(_) => entries,
    };
    let tree = navigation::build_navigation_tree(&entries);
    let result = tui::widgets::menu::menu(guard.terminal(), &theme, &tree)?;
    match result {
        Some(action_ids) => {
            drop(guard);
            let mut exit_code = 0;
            for action_id in &action_ids {
                eprintln!("▶ {}", action_id);
                match execute::execute_module(action_id, &platform) {
                    Ok(0) => {}
                    Ok(_) => {
                        eprintln!("  ✗ {} — module error", action_id);
                        exit_code = 1;
                    }
                    Err(e) => {
                        eprintln!("✗ {} — Error: {}", action_id, e);
                        exit_code = 1;
                    }
                }
            }
            if action_ids.len() > 1 {
                eprintln!();
                if exit_code == 0 {
                    eprintln!("{} succeeded, 0 failed", action_ids.len());
                } else {
                    eprintln!("Batch complete with errors");
                }
            }
            if exit_code != 0 {
                eprintln!("\nHint: Run with verbose output for more details.");
            }
            std::process::exit(exit_code);
        }
        None => println!("Cancelled"),
    }
    Ok(())
}
