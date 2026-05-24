# Phase 2: Interactive Widgets - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-05-24
**Phase:** 02-interactive-widgets
**Mode:** discuss (default)
**Areas discussed:** Checklist interaction model, Checklist rendering style, Radio button visual & behavior, Yes/No widget UX, Text input widget UX, Widget return value conventions

## Discussion

### Checklist interaction model

| Question | Options Presented | User Selected |
|----------|------------------|---------------|
| SPACE toggle behavior | SPACE toggles+ENTER confirms / SPACE toggles+Esc returns current / SPACE toggles+Ctrl+D Done | **SPACE toggles + dedicated Done key (Ctrl+D)** |
| Select All / Deselect All keys | * / - | Ctrl+A / Ctrl+D | a / n | **`*` to select all, `-` to deselect all** |
| Pre-selected items support | Yes | No | **Yes — accept pre-checked indexes** |

### Checklist rendering style

| Question | Options Presented | User Selected |
|----------|------------------|---------------|
| Checkbox glyphs | [x]/[ ] | ☑/☐ Unicode | (x)/( ) | **`[x]` / `[ ]` — classic square brackets** |
| Checked item visual distinction | Only [x] prefix | [x] + dim | Green text | **Only the [x] prefix distinguishes checked** |
| Status line content | "N of M selected" | "Item N of M" + counter | Same as tui_select | **"N of M selected" — selection count** |
| Default help footer | Widget-specific keys | All keys | Minimal | **Show Space=toggle, Ctrl+D=Done, Esc=Cancel, ?=More** |
| Box layout | Same full-screen box | Box without separator | OpenCode decides | **Same full-screen box — consistent** |

### Radio button visual & behavior

| Question | Options Presented | User Selected |
|----------|------------------|---------------|
| Radio glyphs | (•)/(○) with fallback | (×)/( ) ASCII | (●)/(○) larger | **(•)/(○) with ASCII fallback (*)/( )** |
| Selection mechanism | Auto-select on navigation | SPACE to select | **Navigate with arrows, press SPACE to select** |
| Pre-selected default | Yes | No | First item always | **Yes — accept a default index** |

### Yes/No widget UX

| Question | Options Presented | User Selected |
|----------|------------------|---------------|
| Dialog style | Full-screen box | Centered overlay | Inline prompt | **Full-screen box — self-contained** |
| Interaction keys | y/n instant | Arrows + ENTER | Both | **Left/Right arrows + ENTER to confirm** |
| Default choice | No pre-selected | Caller specifies | Yes pre-selected | **No is pre-selected by default** |

### Text input widget UX

| Question | Options Presented | User Selected |
|----------|------------------|---------------|
| Display style | Single-line inline | Full-screen modal | Overlay | **Full-screen modal dialog with input field** |
| Editing keys | Full (BS+arrows+Home/End+Del) | BS only | BS+arrows | **Backspace + Left/Right arrows + Home/End + Delete** |
| Cursor style | Reverse-video block | Underscore | Terminal native | **Reverse-video block cursor (matching tui_select)** |
| Empty input handling | Accept empty | Show error | Caller specifies | **Accept empty input — return empty string** |

### Widget return value conventions

| Question | Options Presented | User Selected |
|----------|------------------|---------------|
| Dual-return pattern across widgets | Yes all follow same | Each widget natural | stdout canonical | **Yes — all widgets follow the same pattern** |
| Checklist multi-select output | Newline-separated | Space-separated | Split formats | **Newline-separated indexes** |
| Zero selections + Done | Return empty | Show error, stay | Caller specifies | **Show error, stay in checklist** |
| Yes/No return format | 'yes' / 'no' | 0 / 1 | Exit code only | **'yes' or 'no' — human readable** |

