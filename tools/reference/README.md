# Reference implementations (pure maths, no engine)

Python checks that the engine code should agree with. They exist so the two agents
building this game — Claude Code in the engine, Claude in text/data — can verify each
other's work without either running the other's tools.

| file | what it checks | engine code |
|---|---|---|
| `daylight_reference.py` | sun declination with 23.44° tilt, sunrise/sunset by latitude and day-of-year, natural twilight, polar night / midnight sun, the stylised 144-min clock (design §F, §F2), season windows and transitions, photoperiod triggers | `scripts/sky/astro.gd`, `scripts/sky/day_cycle.gd`, the season system (Phase 4), plant photoperiod (Phase 6) |
| `daylight_table.csv` | the numbers to match: 11 latitudes × 12 days of the year | run `python3 daylight_reference.py` to regenerate |

Tolerances: 0.05 game hours on any duration, 0.5° on declination, exact season names.
