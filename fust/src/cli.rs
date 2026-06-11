use clap::Parser;

/// Modular developer environment setup utility
#[derive(Debug, Parser)]
#[command(name = "fust", version = env!("CARGO_PKG_VERSION"), about)]
pub struct Cli {
    /// Install modules (comma-separated action IDs)
    #[arg(long = "install")]
    pub install: Option<String>,

    /// Remove modules (comma-separated action IDs)
    #[arg(long = "remove")]
    pub remove: Option<String>,

    /// List available modules
    #[arg(long = "list")]
    pub list: bool,

    /// Skip confirmations (batch mode)
    #[arg(long = "yes")]
    pub yes: bool,

    /// JSON output (with --list)
    #[arg(long = "json")]
    pub json: bool,

    /// Demo: single-select widget
    #[arg(long = "demo-select")]
    pub demo_select: bool,

    /// Demo: checklist widget
    #[arg(long = "demo-checklist")]
    pub demo_checklist: bool,

    /// Demo: radio widget
    #[arg(long = "demo-radio")]
    pub demo_radio: bool,

    /// Demo: yes/no widget
    #[arg(long = "demo-yesno")]
    pub demo_yesno: bool,

    /// Demo: text input widget
    #[arg(long = "demo-text-input")]
    pub demo_text_input: bool,

    /// Demo: hierarchical menu widget
    #[arg(long = "demo-menu")]
    pub demo_menu: bool,
}
