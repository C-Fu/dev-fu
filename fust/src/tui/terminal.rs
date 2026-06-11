use std::io::{self, Stdout};

use crossterm::{
    event::{DisableMouseCapture, EnableMouseCapture},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};

/// RAII terminal guard (per D-14). Drop impl restores terminal state.
/// Panic hook ensures restore on panic. Signal handling via signal-hook.
pub struct TerminalGuard {
    terminal: Terminal<CrosstermBackend<Stdout>>,
    // signal_hook IDs for cleanup
    signal_ids: Vec<signal_hook::SigId>,
}

impl TerminalGuard {
    /// Initialize terminal: raw mode, alternate screen, cursor hide, mouse capture.
    /// Install panic hook and signal handlers (per D-14).
    pub fn init() -> anyhow::Result<Self> {
        // Check TTY (per D-15): fust requires a real terminal
        if !atty_check() {
            anyhow::bail!("fust requires a terminal (TTY). Non-TTY operation is not supported.");
        }

        enable_raw_mode()?;
        let mut stdout = io::stdout();
        execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
        let backend = CrosstermBackend::new(stdout);
        let terminal = Terminal::new(backend)?;

        // Install panic hook (per D-14)
        let default_hook = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            let _ = disable_raw_mode();
            let _ = execute!(io::stdout(), LeaveAlternateScreen, DisableMouseCapture);
            default_hook(info);
        }));

        // Install signal handlers (per D-14)
        let signal_ids = install_signal_handlers()?;

        Ok(Self {
            terminal,
            signal_ids,
        })
    }

    /// Get mutable reference to the underlying ratatui Terminal.
    pub fn terminal(&mut self) -> &mut Terminal<CrosstermBackend<Stdout>> {
        &mut self.terminal
    }

    /// Get current terminal size as a Rect (for ratatui rendering).
    pub fn size(&self) -> anyhow::Result<ratatui::layout::Rect> {
        let s = self.terminal.size()?;
        Ok(ratatui::layout::Rect::new(0, 0, s.width, s.height))
    }
}

impl Drop for TerminalGuard {
    /// Restore terminal on all exit paths (per D-14).
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(
            self.terminal.backend_mut(),
            LeaveAlternateScreen,
            DisableMouseCapture
        );
        // Restore default panic hook
        let _ = std::panic::take_hook();
        // Unregister signal handlers
        for id in &self.signal_ids {
            signal_hook::low_level::unregister(*id);
        }
    }
}

/// Check if stdin/stdout is a TTY (per D-15).
fn atty_check() -> bool {
    use std::io::IsTerminal;
    io::stdout().is_terminal() && io::stdin().is_terminal()
}

/// Install SIGINT/SIGTERM/SIGHUP handlers that restore terminal (per D-14).
fn install_signal_handlers() -> anyhow::Result<Vec<signal_hook::SigId>> {
    use signal_hook::{consts::signal::*, low_level::register};
    let mut ids = Vec::new();
    for &sig in &[SIGINT, SIGTERM, SIGHUP] {
        // SAFETY: signal_hook::low_level::register is unsafe because the closure
        // runs in a signal handler context. Our closure performs best-effort terminal
        // cleanup then exits — acceptable for TUI applications (per D-14).
        let id = unsafe {
            register(sig, move || {
                let _ = disable_raw_mode();
                let _ = execute!(io::stdout(), LeaveAlternateScreen, DisableMouseCapture);
                std::process::exit(128 + sig as i32);
            })?
        };
        ids.push(id);
    }
    Ok(ids)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn atty_check_returns_bool() {
        // Just verify it doesn't panic — actual TTY depends on test environment
        let _result = atty_check();
    }
}
