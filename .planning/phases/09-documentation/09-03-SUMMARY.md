---
phase: 09-documentation
plan: 03
subsystem: documentation
tags: [readme, translation, bahasa-melayu, localization]
requires: [09-01, 09-02]
provides: [README.ms-MY.md (updated), README-Fu.ms-MY.md (new)]
affects: []
tech-stack:
  added: []
  patterns: [markdown-localization, mirror-translation, cross-reference-linking]
key-files:
  created: [README-Fu.ms-MY.md]
  modified: [README.ms-MY.md]
decisions:
  - Preserve all code blocks, URLs, emojis, and technical identifiers verbatim per plan conventions
  - Reuse existing BM translations from old README.ms-MY.md for platform notes, usage, CLI mode, troubleshooting, exit codes
  - Translate only descriptive/narrative text; keep menu trees, ASCII art, and table data values in English
metrics:
  duration: ~5m
  completed: 2026-05-25T23:26:00+08:00
---

# Phase 9 Plan 3: Bahasa Melayu translations — Summary

**One-liner:** README.ms-MY.md restructured to mirror flu.sh-primary README.md in Bahasa Melayu; README-Fu.ms-MY.md created as complete BM translation of fu.sh documentation.

## Tasks Completed

| # | Status | Name | Commit |
|---|--------|------|--------|
| 1 | ✅ | Update README.ms-MY.md to mirror new flu.sh-primary README.md | `99b5f25` |
| 2 | ✅ | Create README-Fu.ms-MY.md mirroring README-Fu.md | `7d99f75` |

## Task Details

### Task 1: README.ms-MY.md restructured (99b5f25)

Rewrote the file from 427 lines (old fu.sh-primary structure) to 246 lines (new flu.sh-primary structure) in Bahasa Melayu:

- **Title:** `# dev-fu — Satu sekerip untuk siap sedia dev environment dalam 99% mesen engkorang ([English](README.md))`
- **flu.sh as primary:** Descriptive paragraph, Quick Start code blocks, 7 feature bullets (Ciri-ciri), menu structure tree (preserved verbatim)
- **Module Architecture (Seni Bina Modul):** How modules work (5 bullets), categories table, architecture diagram — all translated
- **fu.sh as legacy:** Comparison table with translated feature names, cross-reference to README-Fu.ms-MY.md
- **Why dev-fu (Mengapa dev-fu):** 5 bullets adapted from existing BM translation
- **Supported Platforms:** Shell support table + platform table (BM headings, English data)
- **Platform-Specific Notes:** Alpine/BusyBox, macOS, WSL2, Chromebook, Android, ARM — reused existing BM translations
- **Troubleshooting (Penyelesaian Masalah):** 6 issues including 3 new flu.sh-specific ones translated to BM
- **Cross-references:** `[English](README.md)` in header, `[README-Fu.ms-MY.md]` links for fu.sh docs

### Task 2: README-Fu.ms-MY.md created (7d99f75)

Created 340-line new file mirroring README-Fu.md structure in Bahasa Melayu:

- **Title:** `# fu.sh — Bootstrap Dev Environment Monolitik ([English](README-Fu.md))`
- **Legacy notice:** Prominent back-link to README.ms-MY.md in first 5 lines
- **Quick Start:** curl-pipe-bash, all 6 shell variants (code blocks preserved)
- **Screenshot (Skrinshot):** Full ASCII art preserved verbatim
- **Usage (Cara Guna):** Numbered menu list in English, instruction text in BM (reused from old README.ms-MY.md)
- **CLI Mode (Mod Tidak Interaktif):** bash + PowerShell examples (reused BM translation)
- **Comparison table:** fu.sh vs flu.sh with translated feature names
- **What Can Be Installed (Apa Yang Boleh Dipasang):** Category table translated (Kontena, Rangkaian, Bahasa, etc.), tool names and URLs preserved
- **Supported Platforms:** Badge grid + platform table (BM headings)
- **Platform-Specific Notes:** All 7 platform subsections (Linux, Alpine, macOS, WSL2, Windows, ARM, Chromebook, Android) — reused existing BM
- **Troubleshooting (Penyelesaian Masalah):** 3 issues in BM
- **Exit Codes (Kod Keluar):** 3 codes with BM descriptions
- **Bottom back-link:** `*Ini adalah dokumentasi legasi fu.sh...*` linking to README.ms-MY.md

## Verification Results

All plan-specified verifications passed:

| # | Check | Result |
|---|-------|--------|
| 1 | README.ms-MY.md exists | ✅ |
| 2 | BM tagline `Satu sekerip` present | ✅ |
| 3 | Cross-reference to README-Fu.ms-MY.md | ✅ |
| 4 | All BM section headings in ms-MY | ✅ |
| 5 | README-Fu.ms-MY.md exists | ✅ |
| 6 | BM title in Fu present | ✅ |
| 7 | Cross-references top+bottom in Fu (count=2) | ✅ |
| 8 | All BM section headings in Fu | ✅ |
| 9 | All URLs preserved verbatim (9 in ms-MY, 42 in Fu) | ✅ |
| 10 | All emojis preserved (22 in ms-MY menu, 36 in Fu menu) | ✅ |
| 11 | No stubs (TODO/FIXME/placeholder) found | ✅ |

## Deviations from Plan

None — plan executed exactly as written. All BM conventions from the plan's translation reference were followed. All code blocks, URLs, emojis, and technical identifiers were preserved verbatim.

## Cross-Reference Link Matrix

| From | To | Status |
|------|-----|--------|
| README.md | README.ms-MY.md | ✅ (pre-existing) |
| README.ms-MY.md | README.md | ✅ (header `[English]`) |
| README.ms-MY.md | README-Fu.ms-MY.md | ✅ (body links) |
| README-Fu.md | README-Fu.ms-MY.md | ✅ (pre-existing) |
| README-Fu.ms-MY.md | README-Fu.md | ✅ (header `[English]`) |
| README-Fu.ms-MY.md | README.ms-MY.md | ✅ (top legacy notice + bottom back-link) |

## Threat Model Compliance

All STRIDE mitigations satisfied:
- **T-09-07 / T-09-08:** All HTTPS URLs preserved verbatim from English sources — no URL modification
- **T-09-09:** Only descriptive/narrative text translated; all commands, code blocks, technical identifiers preserved verbatim
- **T-09-10:** No secrets, tokens, or credentials in documentation — accepted risk

## Self-Check: PASSED

- [x] `README.ms-MY.md` exists (246 lines, committed as `99b5f25`)
- [x] `README-Fu.ms-MY.md` exists (340 lines, committed as `7d99f75`)
- [x] Both commits present in git log
- [x] All cross-reference links verified bidirectional
- [x] No stubs, no missing sections, no untranslated headings
