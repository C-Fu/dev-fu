use std::io::Stdout;

use ratatui::{
    backend::CrosstermBackend,
    layout::Alignment,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
    Terminal,
};

use crate::platform::PlatformInfo;
use crate::tui::input;
use crate::tui::theme::Theme;

pub const LOGO_LINES: [&str; 6] = [
    "    ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗",
    "██╗   ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║",
    "╚═╝  ██╔╝██╔╝ ██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║",
    "██╗ ██╔╝██╔╝  ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║",
    "╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝",
    "    ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝",
];

pub fn show_splash(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    theme: &Theme,
    platform: &PlatformInfo,
) -> anyhow::Result<()> {
    terminal.draw(|f| {
        let area = f.area();

        let logo_lines: Vec<Line> = LOGO_LINES
            .iter()
            .map(|line| {
                Line::from(Span::styled(
                    line.to_string(),
                    Style::default().fg(Color::Magenta),
                ))
            })
            .collect();

        let logo = Paragraph::new(logo_lines).alignment(Alignment::Center);
        let logo_height = LOGO_LINES.len() as u16 + 1;

        let separator = Paragraph::new(Line::from(Span::styled(
            "─────────────────────────────────────────────────────",
            Style::default().fg(theme.dim),
        )))
        .alignment(Alignment::Center);

        let version_line = Line::from(Span::styled(
            format!("flu v{}", env!("CARGO_PKG_VERSION")),
            Style::default()
                .fg(theme.title)
                .add_modifier(Modifier::BOLD),
        ));
        let platform_line = Line::from(Span::styled(
            platform.display(),
            Style::default().fg(theme.text),
        ));

        let info_block = Block::default()
            .title(Span::styled(
                " flu ",
                Style::default()
                    .fg(theme.title)
                    .add_modifier(Modifier::BOLD),
            ))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.border));

        let info = Paragraph::new(vec![version_line, platform_line])
            .block(info_block)
            .alignment(Alignment::Center);

        let footer = Paragraph::new(Line::from(Span::styled(
            "Press any key to continue...",
            Style::default().fg(theme.dim),
        )))
        .alignment(Alignment::Center);

        let info_height: u16 = 4;
        let footer_height: u16 = 2;
        let separator_height: u16 = 1;
        let total_content = logo_height + separator_height + info_height + footer_height;
        let top_padding = if area.height > total_content {
            (area.height - total_content) / 2
        } else {
            0
        };

        let mut y = area.y + top_padding;
        let width = area.width;

        let logo_area = ratatui::layout::Rect::new(area.x, y, width, logo_height);
        f.render_widget(logo, logo_area);
        y += logo_height;

        let sep_area = ratatui::layout::Rect::new(area.x, y, width, separator_height);
        f.render_widget(separator, sep_area);
        y += separator_height + 1;

        let info_area = ratatui::layout::Rect::new(area.x, y, width, info_height);
        f.render_widget(info, info_area);

        let footer_y = area.y + area.height - 1;
        let footer_area = ratatui::layout::Rect::new(area.x, footer_y, width, 1);
        f.render_widget(footer, footer_area);
    })?;

    let _ = input::read_key()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_logo_lines_count() {
        assert_eq!(LOGO_LINES.len(), 6);
    }

    #[test]
    fn test_logo_lines_nonempty() {
        for line in &LOGO_LINES {
            assert!(!line.is_empty());
            assert!(
                line.contains("█") || line.contains("╗") || line.contains("╔")
                    || line.contains("╚") || line.contains("╝") || line.contains("═")
                    || line.contains("║"),
                "Logo line missing block characters: {}",
                line
            );
        }
    }
}
