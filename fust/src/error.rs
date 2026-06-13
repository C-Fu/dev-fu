#[derive(Debug, Clone, PartialEq)]
#[allow(dead_code)]
pub enum ExitCategory {
    Success,
    Timeout,
    PermissionDenied,
    NotFound,
    Killed,
    Interrupted,
    NetworkError,
    PlatformUnsupported,
    ModuleError,
}

pub fn classify_exit_code(code: i32) -> ExitCategory {
    match code {
        0 => ExitCategory::Success,
        124 => ExitCategory::Timeout,
        126 => ExitCategory::PermissionDenied,
        127 => ExitCategory::NotFound,
        130 => ExitCategory::Interrupted,
        137 => ExitCategory::Killed,
        _ => ExitCategory::ModuleError,
    }
}

pub fn format_hint(category: &ExitCategory) -> &'static str {
    match category {
        ExitCategory::Success => "Operation completed successfully.",
        ExitCategory::Timeout => "Module timed out. Try increasing the timeout with @timeout in the module header, or check for interactive prompts.",
        ExitCategory::PermissionDenied => "Permission denied. Try running with sudo or check file permissions.",
        ExitCategory::NotFound => "Command not found. The required tool may not be installed.",
        ExitCategory::Killed => "Process was killed (SIGKILL). The system may be low on memory.",
        ExitCategory::Interrupted => "Process was interrupted.",
        ExitCategory::NetworkError => "Network error. Check your internet connection and try again.",
        ExitCategory::PlatformUnsupported => "This module does not support your platform. Check @platforms in the module header.",
        ExitCategory::ModuleError => "Module exited with an error. Check the output above for details.",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classify_success() {
        assert_eq!(classify_exit_code(0), ExitCategory::Success);
    }

    #[test]
    fn test_classify_timeout() {
        assert_eq!(classify_exit_code(124), ExitCategory::Timeout);
    }

    #[test]
    fn test_classify_permission_denied() {
        assert_eq!(classify_exit_code(126), ExitCategory::PermissionDenied);
    }

    #[test]
    fn test_classify_not_found() {
        assert_eq!(classify_exit_code(127), ExitCategory::NotFound);
    }

    #[test]
    fn test_classify_killed() {
        assert_eq!(classify_exit_code(137), ExitCategory::Killed);
    }

    #[test]
    fn test_classify_interrupted() {
        assert_eq!(classify_exit_code(130), ExitCategory::Interrupted);
    }

    #[test]
    fn test_classify_other_error() {
        assert_eq!(classify_exit_code(1), ExitCategory::ModuleError);
        assert_eq!(classify_exit_code(99), ExitCategory::ModuleError);
    }

    #[test]
    fn test_format_hint_timeout() {
        let hint = format_hint(&ExitCategory::Timeout);
        assert!(hint.contains("timed out"));
        assert!(hint.contains("timeout"));
    }

    #[test]
    fn test_format_hint_all_nonempty() {
        let categories = [
            ExitCategory::Success,
            ExitCategory::Timeout,
            ExitCategory::PermissionDenied,
            ExitCategory::NotFound,
            ExitCategory::Killed,
            ExitCategory::Interrupted,
            ExitCategory::NetworkError,
            ExitCategory::PlatformUnsupported,
            ExitCategory::ModuleError,
        ];
        for cat in &categories {
            assert!(!format_hint(cat).is_empty(), "Empty hint for {:?}", cat);
        }
    }
}
