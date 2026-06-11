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

    // No args → TUI mode (Phase 16)
    println!("fust v{}", env!("CARGO_PKG_VERSION"));
    println!("{}", platform.display());
    println!("TUI mode not yet implemented (coming in Phase 16)");
    Ok(())
}
