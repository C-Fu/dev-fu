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
}
