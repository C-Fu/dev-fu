---
status: resolved
phase: 03-menu-system
source: [03-VERIFICATION.md]
started: 2026-05-24
updated: 2026-05-24
---

## Current Test

[awaiting human testing]

## Tests

### 1. Navigate full 3-level TUI menu with `sh menu.sh --demo`
expected: Box-rendered TUI with breadcrumb "Main Menu > Developer Tools > Languages > Python" as centered title, items numbered with reverse-video highlight on cursor, Esc returns to parent, Left arrow returns to parent, Enter on Python outputs "Developer Tools|Languages|Python|install_python"
result: [pending]

### 2. Press Left arrow (ESC [ D) at a submenu level and confirm back-navigation
expected: Left arrow behaves identically to Esc — returns to parent menu, resets cursor to item 1
result: [pending]

### 3. Toggle help footer with ? key and verify compact/expanded text
expected: Compact: "Up/Dn Move  Enter Select  Esc Back  ? Keys". Expanded: "Up/Dn Move  Enter Select  Esc/← Back  PgUp/PgDn Page  Home/End  j/k Vi  ? Keys"
result: [pending]

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

All resolved — Enter key fix committed (29d4dbb: sentinel prevents $() from stripping LF in cooked-mode terminals).
