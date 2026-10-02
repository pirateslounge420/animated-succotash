# Working agreement — two agents, one repo

This game is built by two AI agents working the same branch, with the designer (Mike)
directing both: **Claude Code** in the engine, **Claude** (chat) in design, data and
reference maths. This file says who owns what and how we avoid stepping on each other.
Both agents read it at the start of a session: Claude Code gets it automatically, because
`CLAUDE.md` (the brief at the repo root) imports it; Claude in chat reads it from the repo.
The designer can change any line.

The project is **plain Godot 4.3** (design 30 Sept doc §CI), and the planet is **1/10 Earth**
in distance, height and time (4,000 km around; §I).

## Sources of truth, in order
1. **`docs/design/RECONCILIATION_2026-09-30.md`**: the ambient cut and everything decided
   since (§AT onward). New decisions are appended here by Claude (chat) as the designer
   makes them, dated and lettered. **§BR, the last section, is the order of work.** Where it
   disagrees with the 27 Sept doc, it wins.
2. **`docs/design/RECONCILIATION_2026-09-27.md`**: the earlier locked design (§0–§AS). It
   still holds for everything the 30 Sept doc doesn't touch. Its momentum kit, combat and
   shinobi now belong to the separate ninja game (§AT).
3. **`docs/design/LOOK_REFERENCE.md`**: the look. It holds rules R1–R10 and the eye test,
   measured from Mike's twenty favourites (`docs/references/batch4/`). These are findings:
   where they disagree with a locked section (§BU), the locked section stands until Mike
   settles the open calls.
4. **`docs/design/PLANT_SCHEMA.md`**: the plant vocabulary. Data-fill agents use only it, and
   `data/habitat.json` says where plants may grow.
5. **`docs/WORLD_SYSTEMS_SPEC.md`**: the architecture, the phase cards and the per-system
   audit. Phase numbers come from here (2 world-gen, 3 caves, 4 wind, 5 seasons, 6 soil &
   flora, 7 ecology, 8 populations, 9 disturbance, 10 camp life, 11 lore, 12 persistence).
   The order of work is §BR, not the spec's "current phase".
6. `docs/PROGRESS.md`: the log, newest on top. Both agents write entries.
7. Everything else (`CLAUDE.md`, README, DESIGN.md, `docs/OVERVIEW.md`, implementation
   notes, code comments) follows.

## Who owns what
| Claude Code (engine) | Claude (chat) |
|---|---|
| all GDScript and shaders; `project.godot`; scenes | design docs; `docs/design/*` |
| anything judged by eye or feel (lighting, animation, HUD look, gravity tuning) | data files' *new* blocks and `_help` text (`data/*.json`), always additive |
| running the game, screenshots, the check tools in `tools/*.gd` | reference maths and validators in Python (`tools/reference/`, `tools/*_check.py`) |
| `docs/PROGRESS.md` build entries; `docs/implementation-notes.md` | plant data fills via parallel agents; repo-wide consistency audits |
| `docs/HOW_TO_RUN.md` (documents the **built** game) | README/DESIGN/spec corrections when the design changes |
| build and run facts in `CLAUDE.md` | `CLAUDE.md`'s design lines; `docs/OVERVIEW.md` (the shareable summary) |

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
- **One thing at a time.** Claude Code works through §BR in order, plus whatever the
  designer's Claude Code prompt lists. The design doc's other sections are context, not a
  to-do list.
- **No screenshots after every step.** Mike plays on his Mac and reports back. A visual
  pass is checked once, at the end, with the walkabout (§CA). Other passes are checked with
  headless numbers.
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
