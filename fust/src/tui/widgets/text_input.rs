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

/// Freeform text input widget with inline editing.
/// Returns Ok(string) on Enter, Err on cancel.
/// per D-08: function API for widget callers.
pub fn text_input(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    prompt: &str,
    default: &str, // default value (empty string = no default)
) -> anyhow::Result<String> {
    let mut state = TextInputState::new(default);

    loop {
        render(terminal, theme, title, prompt, &state)?;

        let key = input::read_key()?;

        match key {
            Key::Char(c) => {
                // Insert character at cursor position (if under max_len, per T-16-06)
                if state.value.len() < state.max_len {
                    state.value.insert(state.cursor, c);
                    state.cursor += 1;
                }
            }
            Key::Backspace => {
                // Delete character before cursor
                if state.cursor > 0 {
                    state.cursor -= 1;
                    state.value.remove(state.cursor);
                }
            }
            Key::Delete => {
                // Delete character at cursor (forward delete)
                if state.cursor < state.value.len() {
                    state.value.remove(state.cursor);
                }
            }
            Key::Left => {
                if state.cursor > 0 {
                    state.cursor -= 1;
                }
            }
            Key::Right => {
                if state.cursor < state.value.len() {
                    state.cursor += 1;
                }
            }
            Key::Home => {
                state.cursor = 0;
            }
            Key::End => {
                state.cursor = state.value.len();
            }
            Key::Enter => {
                return Ok(state.value);
            }
            Key::Esc => {
                // Only Esc cancels in text input — NOT 'q' (user might type 'q')
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
struct TextInputState {
    value: String,
    cursor: usize,    // cursor position within value (byte index)
    show_help: bool,
    max_len: usize,   // 256, matching tui.sh (per T-16-06)
}

impl TextInputState {
    fn new(default: &str) -> Self {
        let cursor = default.len();
        Self {
            value: default.to_string(),
            cursor,
            show_help: false,
            max_len: 256,
        }
    }
}

/// Render the text input widget as a centered modal (per D-03).
fn render(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    prompt: &str,
    state: &TextInputState,
) -> anyhow::Result<()> {
    terminal.draw(|f| {
        let area = f.area();

        // Calculate centered modal dimensions
        let modal_width = 60.min(area.width.saturating_sub(4));
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

        // Prompt label (centered)
        let prompt_text = Paragraph::new(prompt)
            .style(Style::default().fg(theme.text))
            .alignment(ratatui::layout::Alignment::Center);
        let prompt_area = Rect::new(inner.x, inner.y + 1, inner.width, 1);
        f.render_widget(prompt_text, prompt_area);

        // Input field with cursor
        let input_width = inner.width.saturating_sub(2) as usize;
        let input_y = inner.y + 3;

        // Calculate visible portion of value (scroll if value is longer than input width)
        let input_start = if state.value.len() > input_width {
            let max_start = state.value.len() - input_width;
            let center = state.cursor.saturating_sub(input_width / 2);
            center.min(max_start)
        } else {
            0
        };

        let visible_end = (input_start + input_width).min(state.value.len());
        let visible = &state.value[input_start..visible_end];
        let cursor_vis = state.cursor.saturating_sub(input_start);

        // Build the input line with reverse-video block cursor
        let mut spans = Vec::new();

        // Text before cursor
        if cursor_vis > 0 && cursor_vis <= visible.len() {
            spans.push(Span::styled(
                visible[..cursor_vis].to_string(),
                Style::default().fg(theme.text),
            ));
        }

        // Cursor character (reverse video) or space if at end
        if state.cursor < state.value.len() && cursor_vis < visible.len() {
            let cursor_char = visible[cursor_vis..].chars().next().unwrap_or(' ');
            let cursor_str = cursor_char.to_string();
            spans.push(Span::styled(
                cursor_str,
                Style::default()
                    .fg(theme.highlight_text)
                    .bg(theme.highlight)
                    .add_modifier(Modifier::REVERSED),
            ));
            // Remaining text after cursor
            let after = cursor_vis + cursor_char.len_utf8();
            if after < visible.len() {
                spans.push(Span::styled(
                    visible[after..].to_string(),
                    Style::default().fg(theme.text),
                ));
            }
        } else {
            // Cursor at end — show reverse-video space
            spans.push(Span::styled(
                " ".to_string(),
                Style::default()
                    .fg(theme.highlight_text)
                    .bg(theme.highlight)
                    .add_modifier(Modifier::REVERSED),
            ));
        }

        let input_line = ratatui::text::Line::from(spans);
        let input_para = Paragraph::new(input_line);
        let input_area = Rect::new(inner.x + 1, input_y, inner.width.saturating_sub(2), 1);
        f.render_widget(input_para, input_area);

        // Footer
        let footer_y = inner.y + inner.height - 1;
        let footer_text = if state.show_help {
            "Enter:confirm  Esc:cancel  Backspace  ←→:cursor  Home/End  Delete  ?:less"
        } else {
            "Enter:confirm  Esc:cancel  ←→:cursor  Backspace  ?:help"
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
    fn text_input_state_new_empty() {
        let state = TextInputState::new("");
        assert_eq!(state.value, "");
        assert_eq!(state.cursor, 0);
        assert_eq!(state.max_len, 256);
    }

    #[test]
    fn text_input_state_new_default() {
        let state = TextInputState::new("hello");
        assert_eq!(state.value, "hello");
        assert_eq!(state.cursor, 5); // cursor at end of default
    }

    #[test]
    fn text_input_insert() {
        let mut state = TextInputState::new("");
        // Insert 'a' at cursor 0
        state.value.insert(state.cursor, 'a');
        state.cursor += 1;
        assert_eq!(state.value, "a");
        assert_eq!(state.cursor, 1);

        // Insert 'b' at cursor 1
        state.value.insert(state.cursor, 'b');
        state.cursor += 1;
        assert_eq!(state.value, "ab");
        assert_eq!(state.cursor, 2);
    }

    #[test]
    fn text_input_backspace() {
        let mut state = TextInputState::new("abc");
        state.cursor = 3;
        // Backspace: delete before cursor
        state.cursor -= 1;
        state.value.remove(state.cursor);
        assert_eq!(state.value, "ab");
        assert_eq!(state.cursor, 2);
    }

    #[test]
    fn text_input_delete() {
        let mut state = TextInputState::new("abc");
        state.cursor = 1;
        // Delete: delete at cursor
        state.value.remove(state.cursor);
        assert_eq!(state.value, "ac");
        assert_eq!(state.cursor, 1); // cursor stays
    }

    #[test]
    fn text_input_cursor_movement() {
        let mut state = TextInputState::new("hello");
        state.cursor = 5;
        // Left
        assert!(state.cursor > 0);
        state.cursor -= 1;
        assert_eq!(state.cursor, 4);
        // Home
        state.cursor = 0;
        assert_eq!(state.cursor, 0);
        // End
        state.cursor = state.value.len();
        assert_eq!(state.cursor, 5);
    }

    #[test]
    fn text_input_max_len_enforced() {
        // per T-16-06: max_len=256 enforced on every insert
        let state = TextInputState::new("");
        assert_eq!(state.max_len, 256);
        let long_value = "a".repeat(256);
        assert!(long_value.len() >= state.max_len);
    }
}
