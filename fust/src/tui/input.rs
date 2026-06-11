use crossterm::event::{self, Event, KeyCode, KeyModifiers};
use std::time::Duration;

/// Symbolic key names matching tui.sh's key constants (per D-07).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Key {
    Up,
    Down,
    Left,
    Right,
    Enter,
    Esc,
    PgUp,
    PgDn,
    Home,
    End,
    Space,
    Tab,
    Backspace,
    Delete,
    CtrlD,
    Char(char),    // printable character (includes 'q', '*', '-', letters)
    Number(char),  // digit 0-9 (for go-to, per D-09)
    Help,          // '?' key (per D-10)
    Unknown,
}

/// Read a single key event from the terminal.
/// Blocks until an event is available (up to 100ms poll interval).
/// Maps crossterm KeyCode to our symbolic Key enum.
pub fn read_key() -> anyhow::Result<Key> {
    loop {
        if event::poll(Duration::from_millis(100))? {
            match event::read()? {
                Event::Key(key_event) => return Ok(map_key(key_event)),
                Event::Resize(_, _) => continue, // resize handled by ratatui
                _ => continue,
            }
        }
    }
}

/// Read a key with timeout. Returns None if no key within timeout.
pub fn read_key_timeout(timeout: Duration) -> anyhow::Result<Option<Key>> {
    if event::poll(timeout)? {
        match event::read()? {
            Event::Key(key_event) => Ok(Some(map_key(key_event))),
            _ => Ok(None),
        }
    } else {
        Ok(None)
    }
}

/// Map crossterm KeyEvent to our Key enum.
/// Mirrors tui.sh _tui_read_key() mapping (Section 8).
fn map_key(ke: event::KeyEvent) -> Key {
    // Handle Ctrl combinations first
    if ke.modifiers.contains(KeyModifiers::CONTROL) {
        match ke.code {
            KeyCode::Char('d') => return Key::CtrlD,
            KeyCode::Char('c') => return Key::Esc, // Ctrl-C treated as cancel
            _ => return Key::Unknown,
        }
    }

    match ke.code {
        KeyCode::Up => Key::Up,
        KeyCode::Down => Key::Down,
        KeyCode::Left => Key::Left,
        KeyCode::Right => Key::Right,
        KeyCode::Enter => Key::Enter,
        KeyCode::Esc => Key::Esc,
        KeyCode::PageUp => Key::PgUp,
        KeyCode::PageDown => Key::PgDn,
        KeyCode::Home => Key::Home,
        KeyCode::End => Key::End,
        KeyCode::Backspace => Key::Backspace,
        KeyCode::Delete => Key::Delete,
        KeyCode::Tab => Key::Tab,
        KeyCode::Char(' ') => Key::Space,
        KeyCode::Char('?') => Key::Help,                            // per D-10
        KeyCode::Char(c) if c.is_ascii_digit() => Key::Number(c),   // per D-09
        KeyCode::Char(c) => Key::Char(c),
        _ => Key::Unknown,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crossterm::event::{KeyCode, KeyEvent, KeyModifiers, KeyEventKind, KeyEventState};

    fn make_key_event(code: KeyCode, modifiers: KeyModifiers) -> event::KeyEvent {
        KeyEvent {
            code,
            modifiers,
            kind: KeyEventKind::Press,
            state: KeyEventState::NONE,
        }
    }

    #[test]
    fn map_key_arrows() {
        assert_eq!(
            map_key(make_key_event(KeyCode::Up, KeyModifiers::NONE)),
            Key::Up
        );
        assert_eq!(
            map_key(make_key_event(KeyCode::Down, KeyModifiers::NONE)),
            Key::Down
        );
        assert_eq!(
            map_key(make_key_event(KeyCode::Left, KeyModifiers::NONE)),
            Key::Left
        );
        assert_eq!(
            map_key(make_key_event(KeyCode::Right, KeyModifiers::NONE)),
            Key::Right
        );
    }

    #[test]
    fn map_key_ctrl_d() {
        assert_eq!(
            map_key(make_key_event(
                KeyCode::Char('d'),
                KeyModifiers::CONTROL
            )),
            Key::CtrlD
        );
    }

    #[test]
    fn map_key_digits() {
        for c in '0'..='9' {
            assert_eq!(
                map_key(make_key_event(KeyCode::Char(c), KeyModifiers::NONE)),
                Key::Number(c)
            );
        }
    }

    #[test]
    fn map_key_help() {
        assert_eq!(
            map_key(make_key_event(KeyCode::Char('?'), KeyModifiers::NONE)),
            Key::Help
        );
    }

    #[test]
    fn map_key_space() {
        assert_eq!(
            map_key(make_key_event(KeyCode::Char(' '), KeyModifiers::NONE)),
            Key::Space
        );
    }
}
