use std::io::Stdout;

use ratatui::{
    backend::CrosstermBackend,
    layout::Rect,
    style::{Modifier, Style},
    Terminal,
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
};

use crate::tui::input::{self, Key};
use crate::tui::theme::Theme;

/// Multi-select checklist widget with [x]/[ ] checkboxes.
/// Returns Ok(vec) of 0-based checked indexes on confirm, Ok(empty vec) on cancel.
/// per D-08: function API for widget callers.
pub fn checklist(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    subtitle: &str,
    items: &[&str],
    checked: &[usize], // pre-checked indexes (0-based), like tui.sh --checked
) -> anyhow::Result<Vec<usize>> {
    if items.is_empty() {
        return Ok(vec![]);
    }

    let mut state = ChecklistState::new(terminal, items.len(), checked)?;

    loop {
        render(terminal, theme, title, subtitle, items, &state)?;

        let key = input::read_key()?;

        // Resolve go-to digits on non-number key (per D-09)
        if !matches!(key, Key::Number(_)) && !state.go_digits.is_empty() {
            resolve_go_to(&mut state, items.len());
        }

        match key {
            Key::Up | Key::Char('k') => {
                if state.cursor > 0 {
                    state.cursor -= 1;
                } else {
                    state.cursor = items.len() - 1; // wrap
                }
                state.error_msg = None;
            }
            Key::Down | Key::Char('j') => {
                if state.cursor < items.len() - 1 {
                    state.cursor += 1;
                } else {
                    state.cursor = 0; // wrap
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
            Key::Space => {
                // Toggle current item's checked state
                state.checked[state.cursor] = !state.checked[state.cursor];
                state.selected_count = state.checked.iter().filter(|&&c| c).count();
                state.error_msg = None;
            }
            Key::Char('*') => {
                // Select all (matches tui.sh TUI_KEY_ASTERISK)
                for c in state.checked.iter_mut() {
                    *c = true;
                }
                state.selected_count = items.len();
                state.error_msg = None;
            }
            Key::Char('-') => {
                // Deselect all (matches tui.sh TUI_KEY_MINUS)
                for c in state.checked.iter_mut() {
                    *c = false;
                }
                state.selected_count = 0;
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
                        state.cursor = target - 1;
                        state.go_digits.clear();
                    }
                } else if target > items.len() {
                    state.error_msg = Some(format!("Item {} not found", target));
                    state.go_digits.clear();
                }
            }
            Key::Enter | Key::CtrlD => {
                // Confirm — return checked indexes
                if state.selected_count == 0 {
                    state.error_msg = Some("Select at least one item".to_string());
                } else {
                    let result: Vec<usize> = state
                        .checked
                        .iter()
                        .enumerate()
                        .filter(|(_, &c)| c)
                        .map(|(i, _)| i)
                        .collect();
                    return Ok(result);
                }
            }
            Key::Esc | Key::Char('q') => {
                return Ok(vec![]); // cancel
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
#[allow(dead_code)]
struct ChecklistState {
    cursor: usize,
    scroll: usize,
    checked: Vec<bool>,     // per-item checked state
    selected_count: usize,  // number of checked items
    show_help: bool,        // per D-10
    go_digits: String,      // per D-09
    error_msg: Option<String>,
    page_size: usize,
}

impl ChecklistState {
    fn new(
        terminal: &Terminal<CrosstermBackend<Stdout>>,
        item_count: usize,
        checked: &[usize],
    ) -> anyhow::Result<Self> {
        let size = terminal.size()?;
        let page_size = if size.height > 5 {
            (size.height as usize) - 5
        } else {
            1
        };

        // Initialize checked state from pre-checked indexes
        let mut checked_vec = vec![false; item_count];
        for &idx in checked {
            if idx < item_count {
                checked_vec[idx] = true;
            }
        }
        let selected_count = checked_vec.iter().filter(|&&c| c).count();

        Ok(Self {
            cursor: 0,
            scroll: 0,
            checked: checked_vec,
            selected_count,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size,
        })
    }
}

/// Resolve accumulated go-to digits to a cursor position (per D-09).
fn resolve_go_to(state: &mut ChecklistState, count: usize) {
    if let Ok(target) = state.go_digits.parse::<usize>() {
        if target >= 1 && target <= count {
            state.cursor = target - 1;
        } else {
            state.error_msg = Some(format!("Item {} not found", target));
        }
    }
    state.go_digits.clear();
}

/// Render the checklist widget using ratatui built-in widgets (per D-03).
fn render(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    title: &str,
    subtitle: &str,
    items: &[&str],
    state: &ChecklistState,
) -> anyhow::Result<()> {
    terminal.draw(|f| {
        let area = f.area();

        // Outer block with border
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

        // Subtitle (dimmed) with selection count
        let subtitle_text = Paragraph::new(format!(
            "{}  ({}/{} selected)",
            subtitle,
            state.selected_count,
            items.len()
        ))
        .style(Style::default().fg(theme.dim));
        let subtitle_area = Rect::new(inner.x, inner.y, inner.width, 1);
        f.render_widget(subtitle_text, subtitle_area);

        // Compute list area and footer position
        let list_y = inner.y + 2;
        let footer_y = inner.y + inner.height - 1;

        let list_height = if state.show_help {
            inner.height.saturating_sub(4)
        } else {
            inner.height.saturating_sub(3)
        };
        let list_height = list_height.max(1);
        let list_area = Rect::new(inner.x, list_y, inner.width, list_height);

        // Build list items with checkbox indicators [x]/[ ]
        let list_items: Vec<ListItem> = items
            .iter()
            .enumerate()
            .map(|(i, label)| {
                let is_checked = state.checked[i];
                let is_cursor = i == state.cursor;

                let indicator = if is_checked { "[x] " } else { "[ ] " };
                let indicator_color = if is_checked {
                    theme.checkbox_on
                } else {
                    theme.checkbox_off
                };

                let text_style = if is_cursor {
                    Style::default()
                        .fg(theme.highlight_text)
                        .bg(theme.highlight)
                } else {
                    Style::default().fg(theme.text)
                };

                let indicator_style = if is_cursor {
                    Style::default()
                        .fg(theme.highlight_text)
                        .bg(theme.highlight)
                } else {
                    Style::default().fg(indicator_color)
                };

                ListItem::new(Line::from(vec![
                    Span::styled(indicator, indicator_style),
                    Span::styled(label.to_string(), text_style),
                ]))
            })
            .collect();

        // Use ListState for scroll management (per D-11)
        let mut list_state = ListState::default();
        list_state.select(Some(state.cursor));

        let list = List::new(list_items)
            .highlight_symbol("▸ ");
        f.render_stateful_widget(list, list_area, &mut list_state);

        // Footer (compact/extended based on show_help, per D-10)
        let footer_text = if state.show_help {
            "↑↓/jk:navigate  Space:toggle  *:all  -:none  Enter/Ctrl-D:confirm  Esc:cancel  1-9:go-to  q:quit  ?:less"
        } else {
            "↑↓/jk:navigate  Space:toggle  *:all  -:none  Enter:confirm  ?:help"
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
    fn checklist_state_initial() {
        let state = ChecklistState {
            cursor: 0,
            scroll: 0,
            checked: vec![false, true, false],
            selected_count: 1,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size: 20,
        };
        assert_eq!(state.cursor, 0);
        assert_eq!(state.selected_count, 1);
        assert_eq!(state.checked, vec![false, true, false]);
    }

    #[test]
    fn checklist_toggle() {
        let mut state = ChecklistState {
            cursor: 0,
            scroll: 0,
            checked: vec![false, true, false],
            selected_count: 1,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size: 20,
        };
        // Toggle item 0 on
        state.checked[state.cursor] = !state.checked[state.cursor];
        state.selected_count = state.checked.iter().filter(|&&c| c).count();
        assert!(state.checked[0]);
        assert_eq!(state.selected_count, 2);

        // Toggle item 0 off
        state.checked[state.cursor] = !state.checked[state.cursor];
        state.selected_count = state.checked.iter().filter(|&&c| c).count();
        assert!(!state.checked[0]);
        assert_eq!(state.selected_count, 1);
    }

    #[test]
    fn checklist_select_all() {
        let mut state = ChecklistState {
            cursor: 0,
            scroll: 0,
            checked: vec![false, false, false],
            selected_count: 0,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size: 20,
        };
        // Select all (Key::Char('*'))
        for c in state.checked.iter_mut() {
            *c = true;
        }
        state.selected_count = state.checked.len();
        assert_eq!(state.selected_count, 3);
        assert!(state.checked.iter().all(|&c| c));
    }

    #[test]
    fn checklist_deselect_all() {
        let mut state = ChecklistState {
            cursor: 0,
            scroll: 0,
            checked: vec![true, true, true],
            selected_count: 3,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size: 20,
        };
        // Deselect all (Key::Char('-'))
        for c in state.checked.iter_mut() {
            *c = false;
        }
        state.selected_count = 0;
        assert_eq!(state.selected_count, 0);
        assert!(state.checked.iter().all(|&c| !c));
    }

    #[test]
    fn checklist_prechecked() {
        // Verify checked parameter sets initial state
        let checked_input = vec![0, 2];
        let item_count = 4;
        let mut checked_vec = vec![false; item_count];
        for &idx in &checked_input {
            if idx < item_count {
                checked_vec[idx] = true;
            }
        }
        assert_eq!(checked_vec, vec![true, false, true, false]);
        let count = checked_vec.iter().filter(|&&c| c).count();
        assert_eq!(count, 2);
    }

    #[test]
    fn resolve_go_to_valid() {
        let mut state = ChecklistState {
            cursor: 0,
            scroll: 0,
            checked: vec![false, false, false],
            selected_count: 0,
            show_help: false,
            go_digits: "2".to_string(),
            error_msg: None,
            page_size: 20,
        };
        resolve_go_to(&mut state, 5);
        assert_eq!(state.cursor, 1); // item 2 → index 1
        assert!(state.go_digits.is_empty());
    }
}
