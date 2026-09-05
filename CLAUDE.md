# OpenEmu — macOS Game Emulation

> Read `AGENTS.md` (if present) before this file. This file takes precedence on any conflict.

For full product documentation, see [README.md](README.md).

---

## What it is

**OpenEmu** is an open-source **macOS** app that brings game emulation to first-class citizenship on macOS, leveraging modern frameworks (Metal, Core Animation, Cocoa) and a modular plugin architecture to support dozens of classic gaming systems.

- **Bundle ID:** `org.openemu.OpenEmu`
- **Deployment target:** macOS 12.0 (Monterey) minimum; modern builds require Xcode 14.3 and macOS Ventura
- **Frameworks:** Cocoa (AppKit), Metal, Core Animation, Core Data (migration models), Sparkle (auto-update)
- **Distribution:** Open-source, built via Xcode workspace

---

## Repository layout

| Path | Role |
|------|------|
| `OpenEmu/` | Main app target (Swift + Objective-C) |
| `OpenEmu.xcworkspace` | Xcode workspace (primary) |
| `OpenEmu-metal.xcworkspace` | Alternative Metal-focused workspace |
| `[EmulatorName]/` | Plugin targets (Stella, Mupen64Plus, BSNES, etc.) |
| `docs/PROMPT.md` | Human prompts (input only) |
| `docs/CHAT.md` | Plans, actions, results, and debug log (`## LOG`) |
| `docs/decisions/` | Architecture Decision Records (ADRs) |

---

## Architecture

**Entry point:** `AppDelegate.swift` — lifecycle, window coordination, menu setup.

| Type | Responsibility |
|------|----------------|
| **`AppDelegate`** | App lifecycle, main window, menu bar, library management |
| **`SettingsManager`** | `UserDefaults`-backed persistence for UI state |
| **`LibraryDatabase`** | Core Data models (via xcmappingmodel migrations) for game library |
| **Plugin system** | Emulator cores loaded as bundles at runtime (e.g., Stella, BSNES, Mupen64Plus) |
| **`GameViewController`** | Game playback, controller input, Metal rendering |
| **`PreferencesWindowController`** | Settings UI for gameplay, controls, display |

Key patterns: AppKit view controllers, Core Data for persistence, bundle-based plugin loading, delegate protocols for cross-component signaling.

---

## Build

```bash
# Default (modern, Xcode 14.3+)
open OpenEmu.xcworkspace

# Or via command line
xcodebuild -workspace OpenEmu.xcworkspace -scheme OpenEmu -configuration Release clean build
```

Xcode is authoritative. Target and scheme metadata lives in the workspace.

---

## Conventions

- Small, task-scoped changes; match existing Swift/Objective-C naming and AppKit patterns.
- No force-unwraps; use `guard let` / `if let`.
- Settings changes: update `SettingsManager` and UI together.
- Plugin/emulator-specific work: verify against the target emulator's plugin folder.
- User-facing changes: update `README.md` or `ILLUSTRATIONS.md`.
- Policy/architecture changes: add/update an ADR in `docs/decisions/`.
- Do not modify plugin source folders (Stella, Mupen64Plus, etc.) unless working on plugin integration specifically.

---

## High-risk areas

- [ ] Game library persistence (Core Data migrations across versions)
- [ ] Plugin loading and controller passthrough
- [ ] Metal rendering pipeline and window management
- [ ] Menu bar and AppleScript/automation surfaces
- [ ] Auto-update (Sparkle) logic
- [ ] Sandbox entitlements (if sandboxed)

---

## Chat workflow

1. User posts working prompt from `docs/PROMPT.md`.
2. Assistant responds with **plan only** (approval gate).
3. After approval, assistant appends plan summary to `## LOG` in `docs/CHAT.md`.
4. Execution summaries, fixes, and amendments are appended there as they occur.
5. On completion, user adds: `--> version (BUILDNUMBER)` using `git rev-list --count HEAD`.

ADRs capture durable decisions; `docs/CHAT.md` captures chronological history; `docs/PROMPT.md` holds human prompts only; this file captures stable contributor guidance.
