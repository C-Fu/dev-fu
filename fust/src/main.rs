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
        // Widget demos will be implemented in Plan 16-02
        // For now, verify terminal init/restore works
        let mut guard = tui::terminal::TerminalGuard::init()?;
        let theme = tui::theme::Theme::dark();
        let _size = guard.size()?;

        // Draw a simple demo box to verify rendering works
        guard.terminal().draw(|f| {
            let area = f.area();
            let block = ratatui::widgets::Block::default()
                .title("fust TUI Demo")
                .borders(ratatui::widgets::Borders::ALL)
                .border_style(ratatui::style::Style::default().fg(theme.border))
                .border_type(ratatui::widgets::BorderType::Rounded);
            f.render_widget(block, area);
        })?;

        // Wait for any key press then exit
        let _ = tui::input::read_key()?;
        return Ok(());
    }

    // No args → TUI mode (Phase 17)
    println!("fust v{}", env!("CARGO_PKG_VERSION"));
    println!("{}", platform.display());
    println!("TUI mode not yet implemented (coming in Phase 17)");
    Ok(())
}
