# Phase 16: TUI Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-06-11
**Phase:** 16-tui-engine
**Mode:** discuss (default interactive)
**Areas discussed:** 12

## Areas Discussed

### TUI crate choice
| Question | Options | Selection |
|----------|---------|-----------|
| Which TUI approach for fust? | crossterm only, ratatui, You decide | ratatui |
| Which terminal backend? | Crossterm backend, termion backend, You decide | Crossterm backend |
| Built-in widgets or custom? | Use built-in widgets, Custom widgets, You decide | Use built-in widgets |

### Rendering strategy
| Question | Options | Selection |
|----------|---------|-----------|
| Double-buffer or full redraw? | Double-buffer, Full redraw per frame, You decide | Double-buffer |
| Terminal resize handling? | Auto-adapt, You decide | Auto-adapt |

### Widget state model
| Question | Options | Selection |
|----------|---------|-----------|
| How to model widget state? | Struct per widget, Shared WidgetState enum, You decide | Struct per widget |
| Keyboard input mapping? | Widget-local key handling, Shared key abstraction, You decide | Widget-local key handling |

### Non-TTY fallback
| Question | Options | Selection |
|----------|---------|-----------|
| Port fallbacks or require terminal? | Port all fallbacks, Skip fallbacks, You decide | Skip fallbacks |
| Port async spinner? | Port spinner, Defer spinner, You decide | Defer spinner |

### UTF-8 / locale detection
| Question | Options | Selection |
|----------|---------|-----------|
| Port locale check or assume UTF-8? | Port locale detection, Assume UTF-8, You decide | Port locale detection |

### Widget calling convention
| Question | Options | Selection |
|----------|---------|-----------|
| Widget API style? | Function API, Builder pattern, You decide | Function API |

### Demo / test mode
| Question | Options | Selection |
|----------|---------|-----------|
| Add demo flags? | Port demo flags, Skip demos, You decide | Port demo flags |

### Color palette
| Question | Options | Selection |
|----------|---------|-----------|
| Color palette approach? | Match tui.sh colors, ratatui Color enum, Theme abstraction, You decide | Theme abstraction |
| Default theme? | Dark default, You decide | Dark default |

### Signal / panic handling
| Question | Options | Selection |
|----------|---------|-----------|
| Terminal restore on panic/signal? | RAII guard + panic hook, You decide | RAII guard + panic hook |

### Number-key jump (go-to)
| Question | Options | Selection |
|----------|---------|-----------|
| Port go-to feature? | Port go-to, Skip go-to, You decide | Port go-to |

### Help toggle (? key)
| Question | Options | Selection |
|----------|---------|-----------|
| Port help toggle? | Port help toggle, Always extended, You decide | Port help toggle |

### Scroll behavior
| Question | Options | Selection |
|----------|---------|-----------|
| Match tui.sh scroll or ratatui default? | Match tui.sh scroll, ratatui default scroll, You decide | ratatui default scroll |

## Deferred Ideas
- Async spinner widget — Phase 18/20
- Non-TTY fallback prompts — skipped (require terminal)
- Exact tui.sh scroll behavior match — using ratatui defaults

---

*Discussion log: 2026-06-11*
