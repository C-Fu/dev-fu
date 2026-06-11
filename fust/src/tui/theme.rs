use ratatui::style::Color;

/// Box-drawing characters — UTF-8 on capable terminals, ASCII fallback (per D-12).
#[derive(Debug, Clone, Copy)]
#[allow(dead_code)]
pub struct BoxChars {
    pub tl: char, // top-left
    pub tr: char, // top-right
    pub bl: char, // bottom-left
    pub br: char, // bottom-right
    pub h: char,  // horizontal
    pub v: char,  // vertical
}

impl BoxChars {
    /// Detect from locale — checks LANG/LC_ALL/LC_CTYPE for UTF-8 (per D-12).
    /// Mirrors tui.sh _tui_detect_box_chars() logic exactly.
    pub fn detect() -> Self {
        let locale = format!(
            "{}{}{}",
            std::env::var("LANG").unwrap_or_default(),
            std::env::var("LC_ALL").unwrap_or_default(),
            std::env::var("LC_CTYPE").unwrap_or_default(),
        );
        Self::from_locale(&locale)
    }

    /// Pure function: determine box chars from a locale string (per D-12).
    /// Separated from detect() for testability without env var race conditions.
    pub fn from_locale(locale: &str) -> Self {
        let is_utf8 = locale.to_lowercase().contains("utf-8")
            || locale.to_lowercase().contains("utf8");
        if is_utf8 {
            Self {
                tl: '┌',
                tr: '┐',
                bl: '└',
                br: '┘',
                h: '─',
                v: '│',
            }
        } else {
            Self {
                tl: '+',
                tr: '+',
                bl: '+',
                br: '+',
                h: '-',
                v: '|',
            }
        }
    }
}

/// Theme abstraction (per D-13). Default matches tui.sh dark-terminal colors.
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct Theme {
    pub border: Color,
    pub title: Color,
    pub text: Color,
    pub highlight: Color,      // selected item background/fg
    pub highlight_text: Color, // text color for selected item
    pub dim: Color,            // footer/help text
    pub checkbox_on: Color,
    pub checkbox_off: Color,
    pub error: Color,
    pub box_chars: BoxChars,
}

impl Theme {
    /// Dark default matching tui.sh's color scheme (per D-13).
    pub fn dark() -> Self {
        Self {
            border: Color::Cyan,
            title: Color::White,
            text: Color::White,
            highlight: Color::Cyan,
            highlight_text: Color::Black,
            dim: Color::DarkGray,
            checkbox_on: Color::Green,
            checkbox_off: Color::DarkGray,
            error: Color::Red,
            box_chars: BoxChars::detect(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn box_chars_utf8() {
        // Test pure function with UTF-8 locale string (no env var mutation)
        let bc = BoxChars::from_locale("en_US.UTF-8");
        assert_eq!(bc.tl, '┌');
        assert_eq!(bc.tr, '┐');
        assert_eq!(bc.bl, '└');
        assert_eq!(bc.br, '┘');
        assert_eq!(bc.h, '─');
        assert_eq!(bc.v, '│');
    }

    #[test]
    fn box_chars_ascii() {
        // Test pure function with ASCII locale string (no env var mutation)
        let bc = BoxChars::from_locale("C");
        assert_eq!(bc.tl, '+');
        assert_eq!(bc.tr, '+');
        assert_eq!(bc.bl, '+');
        assert_eq!(bc.br, '+');
        assert_eq!(bc.h, '-');
        assert_eq!(bc.v, '|');
    }

    #[test]
    fn dark_theme_defaults() {
        let theme = Theme::dark();
        assert_eq!(theme.border, Color::Cyan);
        assert_eq!(theme.title, Color::White);
        assert_eq!(theme.text, Color::White);
        assert_eq!(theme.highlight, Color::Cyan);
        assert_eq!(theme.highlight_text, Color::Black);
        assert_eq!(theme.dim, Color::DarkGray);
        assert_eq!(theme.checkbox_on, Color::Green);
        assert_eq!(theme.checkbox_off, Color::DarkGray);
        assert_eq!(theme.error, Color::Red);
    }
}
