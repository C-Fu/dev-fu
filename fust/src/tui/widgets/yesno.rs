use std::io::Stdout;

use ratatui::{
    backend::CrosstermBackend,
    layout::Rect,
    style::{Modifier, Style},
    Terminal,
    text::Span,
    widgets::{Block, Borders, Clear, Paragraph},
};

use crate::tui::input::{self, Key};
use crate::tui::theme::Theme;

/// Yes/No confirmation dialog.
/// Returns Ok(true) for yes, Ok(false) for no, Err on cancel.
/// per D-08: function API for widget callers.
pub fn yesno(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    message: &str,
    default: bool, // true=yes, false=no (matches tui.sh "yes"/"no" default)
) -> anyhow::Result<bool> {
    let mut state = YesNoState {
        selected: default,
        show_help: false,
    };

    loop {
        render(terminal, theme, title, message, &state)?;

        let key = input::read_key()?;

        match key {
            Key::Left | Key::Right | Key::Tab => {
                // Toggle between yes and no
                state.selected = !state.selected;
            }
            Key::Char('y') | Key::Char('Y') => {
                state.selected = true;
            }
            Key::Char('n') | Key::Char('N') => {
                state.selected = false;
            }
            Key::Enter => {
                return Ok(state.selected);
            }
            Key::Esc | Key::Char('q') => {
                anyhow::bail!("Cancelled");
            }
            Key::Help => {
                state.show_help = !state.show_help;
            }
            _ => {}
        }
    }
}

/// Widget state (per D-06)
struct YesNoState {
    selected: bool, // current highlight (true=yes, false=no)
    show_help: bool,
}

/// Render the yesno widget as a centered modal (per D-03).
fn render(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    message: &str,
    state: &YesNoState,
) -> anyhow::Result<()> {
    terminal.draw(|f| {
        let area = f.area();

        // Calculate centered modal dimensions
        let modal_width = 50.min(area.width.saturating_sub(4));
        let modal_height = 9u16;
        let x = (area.width.saturating_sub(modal_width)) / 2;
        let y = (area.height.saturating_sub(modal_height)) / 2;
        let modal_area = Rect::new(x, y, modal_width, modal_height);

        // Clear background behind modal (per D-03: Clear widget)
        f.render_widget(Clear, modal_area);

        // Modal block with border and title
        let block = Block::default()
            .title(Span::styled(
                format!(" {} ", title),
                Style::default()
                    .fg(theme.title)
                    .add_modifier(Modifier::BOLD),
            ))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.border));
        f.render_widget(block, modal_area);

        let inner = modal_area.inner(ratatui::layout::Margin::new(1, 1));
        if inner.width == 0 || inner.height == 0 {
            return;
        }

        // Message text (centered)
        let msg = Paragraph::new(message)
            .style(Style::default().fg(theme.text))
            .alignment(ratatui::layout::Alignment::Center);
        let msg_area = Rect::new(inner.x, inner.y + 1, inner.width, 1);
        f.render_widget(msg, msg_area);

        // Yes/No buttons (centered)
        let yes_style = if state.selected {
            Style::default()
                .fg(theme.highlight_text)
                .bg(theme.highlight)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(theme.text)
        };
        let no_style = if !state.selected {
            Style::default()
                .fg(theme.highlight_text)
                .bg(theme.highlight)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(theme.text)
        };

        let buttons = ratatui::text::Line::from(vec![
            Span::raw("    "),
            Span::styled(" Yes ", yes_style),
            Span::raw("   "),
            Span::styled(" No ", no_style),
        ]);
        let buttons_para = Paragraph::new(buttons)
            .alignment(ratatui::layout::Alignment::Center);
        let buttons_y = inner.y + 3;
        let buttons_area = Rect::new(inner.x, buttons_y, inner.width, 1);
        f.render_widget(buttons_para, buttons_area);

        // Footer
        let footer_y = inner.y + inner.height - 1;
        let footer_text = if state.show_help {
            "←→/Tab:toggle  y/n:select  Enter:confirm  Esc:cancel  ?:less"
        } else {
            "←→:toggle  Enter:confirm  Esc:cancel  ?:help"
        };
        let footer = Paragraph::new(footer_text)
            .style(Style::default().fg(theme.dim));
        let footer_area = Rect::new(inner.x, footer_y, inner.width, 1);
        f.render_widget(footer, footer_area);
    })?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn yesno_state_default_true() {
        let state = YesNoState {
            selected: true,
            show_help: false,
        };
        assert!(state.selected);
    }

    #[test]
    fn yesno_state_default_false() {
        let state = YesNoState {
            selected: false,
            show_help: false,
        };
        assert!(!state.selected);
    }

    #[test]
    fn yesno_toggle() {
        let mut state = YesNoState {
            selected: true,
            show_help: false,
        };
        // Toggle (Left/Right/Tab)
        state.selected = !state.selected;
        assert!(!state.selected);
        state.selected = !state.selected;
        assert!(state.selected);
    }

    #[test]
    fn yesno_help_toggle() {
        let mut state = YesNoState {
            selected: true,
            show_help: false,
        };
        state.show_help = !state.show_help;
        assert!(state.show_help);
        state.show_help = !state.show_help;
        assert!(!state.show_help);
    }
}
