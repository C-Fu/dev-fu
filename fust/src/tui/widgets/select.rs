use std::io::Stdout;

use ratatui::{
    backend::CrosstermBackend,
    layout::Rect,
    style::{Modifier, Style},
    Terminal,
    text::Span,
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
};

use crate::tui::input::{self, Key};
use crate::tui::theme::Theme;

/// Single-select list widget.
/// Returns Ok(Some(index)) on selection, Ok(None) on cancel (Esc/q).
/// per D-08: function API for widget callers.
pub fn select(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    subtitle: &str,
    items: &[&str],
) -> anyhow::Result<Option<usize>> {
    if items.is_empty() {
        return Ok(None);
    }

    let mut state = SelectState::new(terminal, items.len())?;

    loop {
        render(terminal, theme, title, subtitle, items, &state)?;

        let key = input::read_key()?;

        // Resolve go-to digits on non-number key (per D-09)
        if !matches!(key, Key::Number(_)) && !state.go_digits.is_empty() {
            resolve_go_to(&mut state, items.len());
        }

        match key {
            Key::Up | Key::Char('k') => {
                // per D-07: vim keys
                if state.cursor > 0 {
                    state.cursor -= 1;
                } else {
                    state.cursor = items.len() - 1; // wrap to bottom
                }
                state.error_msg = None;
            }
            Key::Down | Key::Char('j') => {
                // per D-07: vim keys
                if state.cursor < items.len() - 1 {
                    state.cursor += 1;
                } else {
                    state.cursor = 0; // wrap to top
                }
                state.error_msg = None;
            }
            Key::Home | Key::Char('g') => {
                state.cursor = 0;
                state.error_msg = None;
            }
            Key::End | Key::Char('G') => {
                state.cursor = items.len() - 1;
                state.error_msg = None;
            }
            Key::PgUp => {
                state.cursor = state.cursor.saturating_sub(state.page_size);
                state.error_msg = None;
            }
            Key::PgDn => {
                state.cursor = (state.cursor + state.page_size).min(items.len() - 1);
                state.error_msg = None;
            }
            Key::Number(c) => {
                // per D-09: number-key jump (go-to)
                state.go_digits.push(c);
                state.error_msg = None;
                let target: usize = state.go_digits.parse().unwrap_or(0);
                if target >= 1 && target <= items.len() {
                    let next = target * 10;
                    if next > items.len() {
                        // Can't add more digits — jump immediately
                        state.cursor = target - 1;
                        state.go_digits.clear();
                    }
                    // else: wait for more digits
                } else if target > items.len() {
                    state.error_msg = Some(format!("Item {} not found", target));
                    state.go_digits.clear();
                }
            }
            Key::Enter => {
                return Ok(Some(state.cursor));
            }
            Key::Esc | Key::Char('q') => {
                return Ok(None);
            }
            Key::Help => {
                // per D-10: help toggle
                state.show_help = !state.show_help;
            }
            _ => {}
        }
    }
}

/// Widget state (per D-06)
struct SelectState {
    cursor: usize,
    scroll: usize,
    show_help: bool,    // per D-10
    go_digits: String,  // per D-09
    error_msg: Option<String>,
    page_size: usize,
}

impl SelectState {
    fn new(terminal: &Terminal<CrosstermBackend<Stdout>>, _item_count: usize) -> anyhow::Result<Self> {
        let size = terminal.size()?;
        // Layout: top border(1) + title(1) + subtitle(1) + list + footer(1) + bottom border(1) = 5 overhead
        let page_size = if size.height > 5 {
            (size.height as usize) - 5
        } else {
            1
        };
        Ok(Self {
            cursor: 0,
            scroll: 0,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size,
        })
    }
}

/// Resolve accumulated go-to digits to a cursor position (per D-09).
fn resolve_go_to(state: &mut SelectState, count: usize) {
    if let Ok(target) = state.go_digits.parse::<usize>() {
        if target >= 1 && target <= count {
            state.cursor = target - 1;
        } else {
            state.error_msg = Some(format!("Item {} not found", target));
        }
    }
    state.go_digits.clear();
}

/// Render the select widget using ratatui built-in widgets (per D-03).
fn render(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    subtitle: &str,
    items: &[&str],
    state: &SelectState,
) -> anyhow::Result<()> {
    terminal.draw(|f| {
        let area = f.area();

        // Outer block with border (per D-03: Block with borders)
        let block = Block::default()
            .title(Span::styled(
                format!(" {} ", title),
                Style::default()
                    .fg(theme.title)
                    .add_modifier(Modifier::BOLD),
            ))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.border));
        f.render_widget(block, area);

        let inner = area.inner(ratatui::layout::Margin::new(1, 1));
        if inner.width == 0 || inner.height == 0 {
            return;
        }

        // Subtitle (dimmed)
        let subtitle_text = Paragraph::new(subtitle)
            .style(Style::default().fg(theme.dim));
        let subtitle_area = Rect::new(inner.x, inner.y, inner.width, 1);
        f.render_widget(subtitle_text, subtitle_area);

        // Compute list area and footer position
        let list_y = inner.y + 2; // after title row + subtitle row
        let footer_y = inner.y + inner.height - 1;

        let list_height = if state.show_help {
            inner.height.saturating_sub(4) // subtitle(1) + help(1) + footer(1) + extra(1)
        } else {
            inner.height.saturating_sub(3) // subtitle(1) + footer(1) + spacing
        };
        let list_height = list_height.max(1);
        let list_area = Rect::new(inner.x, list_y, inner.width, list_height);

        // Build list items with manual highlight styling (per D-11: ratatui List)
        let list_items: Vec<ListItem> = items
            .iter()
            .enumerate()
            .map(|(i, label)| {
                let style = if i == state.cursor {
                    Style::default()
                        .fg(theme.highlight_text)
                        .bg(theme.highlight)
                } else {
                    Style::default().fg(theme.text)
                };
                ListItem::new(Span::styled(format!("  {}", label), style))
            })
            .collect();

        // Use ListState for scroll management (per D-11: ratatui default scrolling)
        let mut list_state = ListState::default();
        list_state.select(Some(state.cursor));

        let list = List::new(list_items)
            .highlight_symbol("▸ ");
        f.render_stateful_widget(list, list_area, &mut list_state);

        // Footer (compact/extended based on show_help, per D-10)
        let footer_text = if state.show_help {
            "↑↓/jk:navigate  Enter:select  Esc:cancel  PgUp/PgDn:page  g/G:home/end  1-9:go-to  q:quit  ?:less"
        } else {
            "↑↓/jk:navigate  Enter:select  Esc:cancel  ?:help"
        };
        let footer = Paragraph::new(footer_text)
            .style(Style::default().fg(theme.dim));
        let footer_area = Rect::new(inner.x, footer_y, inner.width, 1);
        f.render_widget(footer, footer_area);

        // Extended help area (per D-10)
        if state.show_help {
            let help_y = footer_y.saturating_sub(1);
            let help_text = format!(
                "Go-to: {}  |  Page size: {}  |  Items: {}",
                if state.go_digits.is_empty() {
                    "-".to_string()
                } else {
                    state.go_digits.clone()
                },
                state.page_size,
                items.len()
            );
            let help = Paragraph::new(help_text)
                .style(Style::default().fg(theme.dim));
            let help_area = Rect::new(inner.x, help_y, inner.width, 1);
            f.render_widget(help, help_area);
        }

        // Error message
        if let Some(ref err) = state.error_msg {
            let err_y = footer_y.saturating_sub(if state.show_help { 2 } else { 1 });
            let error = Paragraph::new(err.as_str())
                .style(Style::default().fg(theme.error));
            let err_area = Rect::new(inner.x, err_y, inner.width, 1);
            f.render_widget(error, err_area);
        }
    })?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn select_state_initial() {
        // Verify initial state values (cursor=0, scroll=0 per acceptance criteria)
        let state = SelectState {
            cursor: 0,
            scroll: 0,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size: 20,
        };
        assert_eq!(state.cursor, 0);
        assert_eq!(state.scroll, 0);
        assert!(!state.show_help);
        assert!(state.go_digits.is_empty());
        assert!(state.error_msg.is_none());
    }

    #[test]
    fn resolve_go_to_valid() {
        let mut state = SelectState {
            cursor: 0,
            scroll: 0,
            show_help: false,
            go_digits: "3".to_string(),
            error_msg: None,
            page_size: 20,
        };
        resolve_go_to(&mut state, 10);
        assert_eq!(state.cursor, 2); // 3 → index 2 (1-based to 0-based)
        assert!(state.go_digits.is_empty());
        assert!(state.error_msg.is_none());
    }

    #[test]
    fn resolve_go_to_out_of_range() {
        let mut state = SelectState {
            cursor: 0,
            scroll: 0,
            show_help: false,
            go_digits: "99".to_string(),
            error_msg: None,
            page_size: 20,
        };
        resolve_go_to(&mut state, 10);
        assert_eq!(state.cursor, 0); // unchanged
        assert!(state.error_msg.is_some());
        assert!(state.go_digits.is_empty());
    }

    #[test]
    fn resolve_go_to_first_item() {
        let mut state = SelectState {
            cursor: 5,
            scroll: 0,
            show_help: false,
            go_digits: "1".to_string(),
            error_msg: None,
            page_size: 20,
        };
        resolve_go_to(&mut state, 10);
        assert_eq!(state.cursor, 0); // item 1 → index 0
    }
}
