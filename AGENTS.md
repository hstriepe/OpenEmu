# Agents

This file lists Claude agents and specialized tools available for OpenEmu work.

## Active agents

| Agent | When to use | Notes |
|-------|------------|-------|
| **Explore** | Finding files, grepping symbols, locating code patterns across the codebase | Read-only; fast; use for "where is X defined" or cross-file search. |
| **Plan** | Designing implementation strategy, identifying critical files, architectural trade-offs | Use before major refactors or plugin integration work. |
| **General-purpose** | Multi-step research, complex debugging, end-to-end implementation | Default for most tasks; full tool access. |

## Skills

| Skill | When to use |
|-------|------------|
| **`/run`** | Launch OpenEmu in Xcode/simulator to verify UI changes or gameplay fixes. |
| **`/code-review`** | Review pending changes for correctness, simplification, efficiency. |
| **`/init`** | Initialize or refresh CLAUDE.md documentation. |

## External references

- **Xcode:** Authoritative for build configuration, target membership, scheme settings.
- **Plugin sources:** Each emulator (Stella, BSNES, Mupen64Plus, etc.) has its own repository; changes to plugin logic should reference upstream repos.
- **Issue tracker:** GitHub Issues on this repository (OpenEmu/OpenEmu).
