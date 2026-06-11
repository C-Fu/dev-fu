mod cli;
mod menu;
mod platform;
mod tui;

use clap::Parser;

fn main() -> anyhow::Result<()> {
    let args = cli::Cli::parse();

    // Detect platform (always, matching flu.sh behavior)
    let platform = platform::detect()?;

    if args.list {
        // Delegate to menu module (implemented in task 2)
        let entries = menu::parse_menu_db();
        if args.json {
            menu::print_json(&entries);
        } else {
            menu::print_table(&entries);
        }
        return Ok(());
    }

    if args.install.is_some() || args.remove.is_some() {
        println!("Batch mode not yet implemented (coming in Phase 19)");
        std::process::exit(1);
    }

    // Demo flags (per D-16) — standalone widget testing
    if args.demo_select
        || args.demo_checklist
        || args.demo_radio
        || args.demo_yesno
        || args.demo_text_input
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
        }
        return Ok(());
    }

    // No args → TUI mode (Phase 17)
    println!("fust v{}", env!("CARGO_PKG_VERSION"));
    println!("{}", platform.display());
    println!("TUI mode not yet implemented (coming in Phase 17)");
    Ok(())
}
