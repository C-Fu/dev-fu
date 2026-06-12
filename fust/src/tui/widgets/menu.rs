use std::io::Stdout;

use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Terminal,
};

use crate::navigation::{ActionQueue, MenuTree};
use crate::tui::input::{self, Key};
use crate::tui::theme::Theme;

pub fn menu(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    tree: &MenuTree,
) -> anyhow::Result<Option<Vec<String>>> {
    let mut state = MenuState::new(terminal)?;

    loop {
        let children = tree.get_children(&state.path);
        if children.is_empty() {
            return Ok(None);
        }
        if state.cursor >= children.len() {
            state.cursor = children.len() - 1;
        }

        render(terminal, theme, tree, &state, &children)?;

        let key = input::read_key()?;

        if !matches!(key, Key::Number(_)) && !state.go_digits.is_empty() {
            resolve_go_to(&mut state, children.len());
        }

        match key {
            Key::Up | Key::Char('k') => {
                if state.cursor > 0 {
                    state.cursor -= 1;
                } else {
                    state.cursor = children.len() - 1;
                }
                state.error_msg = None;
            }
            Key::Down | Key::Char('j') => {
                if state.cursor < children.len() - 1 {
                    state.cursor += 1;
                } else {
                    state.cursor = 0;
                }
                state.error_msg = None;
            }
            Key::Home | Key::Char('g') => {
                state.cursor = 0;
                state.error_msg = None;
            }
            Key::End | Key::Char('G') => {
                state.cursor = children.len() - 1;
                state.error_msg = None;
            }
            Key::PgUp => {
                state.cursor = state.cursor.saturating_sub(state.page_size);
                state.error_msg = None;
            }
            Key::PgDn => {
                state.cursor = (state.cursor + state.page_size).min(children.len() - 1);
                state.error_msg = None;
            }
            Key::Number(c) => {
                state.go_digits.push(c);
                state.error_msg = None;
                let target: usize = state.go_digits.parse().unwrap_or(0);
                if target >= 1 && target <= children.len() {
                    let next = target * 10;
                    if next > children.len() {
                        state.cursor = target - 1;
                        state.go_digits.clear();
                    }
                } else if target > children.len() {
                    state.error_msg = Some(format!("Item {} not found", target));
                    state.go_digits.clear();
                }
            }
            Key::Space => {
                let child_idx = children[state.cursor];
                if tree.is_leaf(child_idx) {
                    if let Some(action_id) = tree.get_action_id(child_idx) {
                        state.queue.toggle(action_id);
                    }
                }
                state.error_msg = None;
            }
            Key::Enter => {
                let child_idx = children[state.cursor];
                if !tree.is_leaf(child_idx) {
                    let child_label = tree.nodes[child_idx].label.clone();
                    state.path.push(child_label);
                    state.cursor = 0;
                    state.scroll = 0;
                }
                state.error_msg = None;
            }
            Key::Char('c') => {
                if state.queue.count() > 0 {
                    return Ok(Some(state.queue.to_vec()));
                }
                state.error_msg = Some("Queue is empty — press Space to add items".to_string());
            }
            Key::Esc | Key::Char('q') => {
                if state.path.is_empty() {
                    return Ok(None);
                } else {
                    state.path.pop();
                    state.cursor = 0;
                    state.scroll = 0;
                }
            }
            Key::Left | Key::Backspace => {
                if !state.path.is_empty() {
                    state.path.pop();
                    state.cursor = 0;
                    state.scroll = 0;
                }
            }
            Key::Help => {
                state.show_help = !state.show_help;
            }
            _ => {}
        }
    }
}

struct MenuState {
    path: Vec<String>,
    cursor: usize,
    scroll: usize,
    show_help: bool,
    go_digits: String,
    error_msg: Option<String>,
    page_size: usize,
    queue: ActionQueue,
}

impl MenuState {
    fn new(terminal: &Terminal<CrosstermBackend<Stdout>>) -> anyhow::Result<Self> {
        let size = terminal.size()?;
        let page_size = if size.height > 5 {
            (size.height as usize) - 5
        } else {
            1
        };
        Ok(Self {
            path: Vec::new(),
            cursor: 0,
            scroll: 0,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size,
            queue: ActionQueue::new(),
        })
    }
}

fn resolve_go_to(state: &mut MenuState, count: usize) {
    if let Ok(target) = state.go_digits.parse::<usize>() {
        if target >= 1 && target <= count {
            state.cursor = target - 1;
        } else {
            state.error_msg = Some(format!("Item {} not found", target));
        }
    }
    state.go_digits.clear();
}

fn render(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    tree: &MenuTree,
    state: &MenuState,
    children: &[usize],
) -> anyhow::Result<()> {
    terminal.draw(|f| {
        let area = f.area();

        let has_queue = state.queue.count() > 0;
        let wide_enough = area.width > 60;

        let (menu_area, desc_area, queue_area) = if has_queue && wide_enough {
            let chunks = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Percentage(55),
                    Constraint::Percentage(25),
                    Constraint::Percentage(20),
                ])
                .split(area);
            (chunks[0], Some(chunks[1]), Some(chunks[2]))
        } else if wide_enough {
            let chunks = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Percentage(60),
                    Constraint::Percentage(40),
                ])
                .split(area);
            (chunks[0], Some(chunks[1]), None)
        } else {
            (area, None, None)
        };

        let breadcrumb = tree.get_breadcrumb(&state.path);
        let depth = state.path.len();
        let border_color = theme.border_color_for_depth(depth);
        let block = Block::default()
            .title(Span::styled(
                format!(" {} ", breadcrumb),
                Style::default()
                    .fg(border_color)
                    .add_modifier(Modifier::BOLD),
            ))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(border_color));
        f.render_widget(block.clone(), menu_area);

        let inner = menu_area.inner(ratatui::layout::Margin::new(1, 1));
        if inner.width == 0 || inner.height == 0 {
            return;
        }

        let list_y = inner.y + 1;
        let footer_y = inner.y + inner.height - 1;

        let list_height = if state.show_help {
            inner.height.saturating_sub(4)
        } else {
            inner.height.saturating_sub(3)
        };
        let list_height = list_height.max(1);
        let list_area = Rect::new(inner.x, list_y, inner.width, list_height);

        let list_items: Vec<ListItem> = children
            .iter()
            .enumerate()
            .map(|(i, &child_idx)| {
                let node = &tree.nodes[child_idx];
                let is_leaf = tree.is_leaf(child_idx);
                let is_queued = node
                    .action_id
                    .as_deref()
                    .map(|aid| state.queue.contains(aid))
                    .unwrap_or(false);

                let prefix = if is_leaf {
                    if is_queued {
                        "[x] "
                    } else {
                        "[ ] "
                    }
                } else {
                    "    "
                };

                let suffix = if !is_leaf { " >" } else { "" };

                let style = if i == state.cursor {
                    Style::default()
                        .fg(theme.highlight_text)
                        .bg(theme.highlight)
                } else if is_queued {
                    Style::default().fg(theme.checkbox_on)
                } else {
                    Style::default().fg(theme.text)
                };

                let text = format!("  {}{}) {}{}", prefix, i + 1, node.label, suffix);
                ListItem::new(Span::styled(text, style))
            })
            .collect();

        let mut list_state = ListState::default();
        list_state.select(Some(state.cursor));

        let list = List::new(list_items).highlight_symbol("▸ ");
        f.render_stateful_widget(list, list_area, &mut list_state);

        let queue_count_text = if state.queue.count() > 0 {
            format!("  {} selected", state.queue.count())
        } else {
            String::new()
        };

        let footer_text = if state.show_help {
            "↑↓/jk:navigate  Space:queue  Enter:descend  ⌫:back  c:confirm queue  PgUp/PgDn:page  g/G:home/end  1-9:go-to  q:quit  ?:less"
        } else {
            "↑↓/jk:navigate  Space:queue  Enter:descend  ⌫:back  c:confirm  ?:help"
        };

        let footer_spans = vec![
            Span::styled(footer_text, Style::default().fg(theme.dim)),
            Span::styled(
                queue_count_text,
                Style::default().fg(theme.checkbox_on),
            ),
        ];
        let footer = Paragraph::new(Line::from(footer_spans));
        let footer_area = Rect::new(inner.x, footer_y, inner.width, 1);
        f.render_widget(footer, footer_area);

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
                children.len()
            );
            let help = Paragraph::new(help_text).style(Style::default().fg(theme.dim));
            let help_area = Rect::new(inner.x, help_y, inner.width, 1);
            f.render_widget(help, help_area);
        }

        if let Some(ref err) = state.error_msg {
            let err_y = footer_y.saturating_sub(if state.show_help { 2 } else { 1 });
            let error = Paragraph::new(err.as_str()).style(Style::default().fg(theme.error));
            let err_area = Rect::new(inner.x, err_y, inner.width, 1);
            f.render_widget(error, err_area);
        }

        if let Some(qa) = queue_area {
            let queue_block = Block::default()
                .title(Span::styled(
                    " Queue ",
                    Style::default()
                        .fg(theme.title)
                        .add_modifier(Modifier::BOLD),
                ))
                .borders(Borders::ALL)
                .border_style(Style::default().fg(border_color));
            f.render_widget(queue_block, qa);

            let queue_inner = qa.inner(ratatui::layout::Margin::new(1, 1));
            if queue_inner.width > 0 && queue_inner.height > 0 {
                let confirm_hint = Paragraph::new(Span::styled(
                    "c : confirm install",
                    Style::default().fg(theme.dim),
                ));
                let hint_area = Rect::new(queue_inner.x, queue_inner.y, queue_inner.width, 1);
                f.render_widget(confirm_hint, hint_area);

                let list_y = queue_inner.y + 1;
                let list_height = queue_inner.height.saturating_sub(1);
                if list_height > 0 {
                    let queued_items = state.queue.to_vec();
                    let queue_lines: Vec<ListItem> = queued_items
                        .iter()
                        .enumerate()
                        .map(|(i, action_id)| {
                            ListItem::new(Span::styled(
                                format!("{}. {}", i + 1, action_id),
                                Style::default().fg(theme.text),
                            ))
                        })
                        .collect();
                    let queue_list = List::new(queue_lines);
                    let list_area = Rect::new(queue_inner.x, list_y, queue_inner.width, list_height);
                    f.render_widget(queue_list, list_area);
                }
            }
        }

        if let Some(da) = desc_area {
            let desc_block = Block::default()
                .title(Span::styled(
                    " Info ",
                    Style::default()
                        .fg(theme.title)
                        .add_modifier(Modifier::BOLD),
                ))
                .borders(Borders::ALL)
                .border_style(Style::default().fg(border_color));
            f.render_widget(desc_block, da);

            let desc_inner = da.inner(ratatui::layout::Margin::new(1, 1));
            if desc_inner.width > 0 && desc_inner.height > 0 {
                let selected_idx = children.get(state.cursor).copied();
                let desc_lines: Vec<Line> = if let Some(idx) = selected_idx {
                    let node = &tree.nodes[idx];
                    let is_leaf = tree.is_leaf(idx);
                    let kind = if is_leaf { "Action" } else { "Category" };

                    let mut lines = vec![
                        Line::from(Span::styled(
                            node.label.clone(),
                            Style::default()
                                .fg(theme.title)
                                .add_modifier(Modifier::BOLD),
                        )),
                        Line::from(Span::styled(
                            format!("Type: {}", kind),
                            Style::default().fg(theme.text),
                        )),
                    ];

                    if let Some(ref action_id) = node.action_id {
                        lines.push(Line::from(Span::styled(
                            format!("Module: {}.sh", action_id),
                            Style::default().fg(theme.text),
                        )));
                    }

                    if is_leaf {
                        lines.push(Line::from(Span::styled(
                            "Press Space to queue",
                            Style::default().fg(theme.dim),
                        )));
                    } else {
                        let child_count = node.children.len();
                        lines.push(Line::from(Span::styled(
                            format!("{} items inside", child_count),
                            Style::default().fg(theme.text),
                        )));
                        lines.push(Line::from(Span::styled(
                            "Press Enter to open",
                            Style::default().fg(theme.dim),
                        )));
                    }

                    let path_str = node.path.join(" > ");
                    lines.push(Line::from(""));
                    lines.push(Line::from(Span::styled(
                        path_str,
                        Style::default().fg(theme.dim),
                    )));

                    lines
                } else {
                    vec![Line::from(Span::styled(
                        "No selection",
                        Style::default().fg(theme.dim),
                    ))]
                };

                let desc = Paragraph::new(desc_lines)
                    .wrap(ratatui::widgets::Wrap { trim: false });
                f.render_widget(desc, desc_inner);
            }
        }
    })?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_menu_state_initial() {
        let state = MenuState {
            path: Vec::new(),
            cursor: 0,
            scroll: 0,
            show_help: false,
            go_digits: String::new(),
            error_msg: None,
            page_size: 20,
            queue: ActionQueue::new(),
        };
        assert!(state.path.is_empty());
        assert_eq!(state.cursor, 0);
        assert_eq!(state.queue.count(), 0);
    }

    #[test]
    fn test_breadcrumb_in_render() {
        let entries = crate::menu::parse_menu_db();
        let tree = crate::navigation::build_navigation_tree(&entries);
        let breadcrumb = tree.get_breadcrumb(&[]);
        assert_eq!(breadcrumb, "Main Menu");
    }

    #[test]
    fn test_queue_toggle_in_menu() {
        let mut queue = ActionQueue::new();
        queue.toggle("install_go");
        assert!(queue.contains("install_go"));
        assert_eq!(queue.count(), 1);
        queue.toggle("install_go");
        assert!(!queue.contains("install_go"));
        assert_eq!(queue.count(), 0);
    }
}
