# Working agreement — two agents, one repo

This game is built by two AI agents working the same branch, with the designer (Mike)
directing both: **Claude Code** in the engine, **Claude** (chat) in design, data and
reference maths. This file says who owns what and how we avoid stepping on each other.
Both agents read it at the start of a session. The designer can change any line.

## Sources of truth, in order
1. **`docs/design/RECONCILIATION_2026-09-27.md`** — the locked design (thesis, §0–V).
   New decisions are appended there by Claude (chat) as the designer makes them, dated.
2. **`docs/design/PLANT_SCHEMA.md`** — the plant vocabulary; data-fill agents use only it.
3. **`docs/WORLD_SYSTEMS_SPEC.md`** — the phased roadmap and per-system audit. Phase
   numbers come from here (2 world-gen, 3 caves, 4 wind, 5 seasons, 6 soil & flora,
   7 ecology, 8 populations, 9 disturbance, 10 camp life, 11 lore, 12 persistence).
4. `docs/PROGRESS.md` — the log, newest on top. Both agents write entries.
5. Everything else (README, DESIGN.md, implementation-notes, code comments) follows.

## Who owns what
| Claude Code (engine) | Claude (chat) |
|---|---|
| all GDScript and shaders; `project.godot`; scenes | design docs; `docs/design/*` |
| anything judged by eye or feel (lighting, animation, HUD look, gravity tuning) | data files' *new* blocks and `_help` text (`data/*.json`), always additive |
| running the game, screenshots, the check tools in `tools/*.gd` | reference maths and validators in Python (`tools/reference/`, `tools/*_check.py`) |
| `docs/PROGRESS.md` build entries; `docs/implementation-notes.md` | plant data fills via parallel agents; repo-wide consistency audits |
| `docs/HOW_TO_RUN.md` (documents the **built** game) | README/DESIGN/spec corrections when the design changes |

Grey areas: `scripts/core/controls.gd` bindings and one-line data-driven constants may be
edited by either, with a commit message that says so. Neither agent rewrites the other's
files wholesale.

## Rules
- **Pull before every push.** Rebase, never force. If the other agent pushed to the same
  file, merge by hand and keep both changes.
- **Data is additive.** New tunables are added with defaults and a `_help` line; a value
  the design mandates is changed with the section number in the help text. Blocks the
  code does not read yet are prefixed `[NOT WIRED YET — design §X]` and Claude Code
  removes the prefix when it wires them.
- **Docs describe what exists.** `HOW_TO_RUN.md` and code comments describe the built
  game; unbuilt design is marked "(design §X, not built yet)". The design doc describes
  the intended game and never claims something is built.
- **One phase at a time.** Claude Code works the current phase in the spec plus whatever
  the designer's Claude Code prompt lists; the design doc's later sections are context,
  not a to-do list.
- **Every design section gets a section letter** (§A, §B, …) so prompts, commit messages,
  help text and progress entries can point at it in two characters.
- **Verification is cross-agent.** Claude Code's `tools/*_check.gd` verify the engine;
  Claude's `tools/reference/*.py` and validators verify data and maths. Where both exist
  for one system (day length, plant data), they must agree.
- **The designer's word is final.** Either agent flags a contradiction it notices — in
  the design doc, the spec, or between the two of us — in its next message to the
  designer, and does not silently pick a side.

## Parallel work (Claude, chat)
Big data jobs are fanned out to parallel sub-agents, one file per agent, each choosing
only from the locked vocabulary and running the validator before it finishes; results
are committed together. Read-only audits use a separate agent that reports file:line
contradictions for a human-readable fix pass.
