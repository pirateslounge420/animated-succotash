# PROGRESS.md — running log (newest on top)

Claude Code prepends 3–6 lines every session. The designer signs off phases here.

---

## 2026-09-26 — Phase 0 signed off; spec patched for Phase 1 (docs only, nothing built)
- **Phase 0 — Look & Light signed off** by the designer on the dusk river shot. Current phase: **Phase 1 — Player feel, hitboxes, audio**.
- Designer's answers: stamp stays 40 km; ruins and mythicals stay on the stamp (test bed for Phases 6–10); dusk clouds fine as shot; fire trial: #FFA050 for the light on folk and props, #FFB020 core and #FF4A00 coals kept. Trial shot sent (runtime override only; the code change waits for Go).
- Spec: D1 scale note (400 km through Phase 11, maybe 1/10–1/30 Earth later; two-tier storage). D3 rewritten against the code: where every field lives now, a proposed home and owner for each missing one, regions as 4×4 cell blocks (~8 MB ledger on the full planet). D4 gains tree lifespans. Phase 1 card gains the branch graph, climbing, gibbon brachiation, and the ripple / Night Rider / Pond Crawler text verbatim. Phase 2 gains the memory and current checks. Snags and dead wood run across Phases 5, 6, 8 and 9, plus R3 (woodpeckers, owls) and Part F (two checks).
- Next: Phase 1 Prompt A (audit + minimal changes), then wait for Go. The ripple, Night Rider and Pond Crawler agents are still in their copies; they get audited against the patched card before any merge.
- Open: D3 flags (sky and eased weather not on World; new `flora.cavities`; sparse storage for a 10× planet; felled/burned trees as stored deltas). Band grouping (alpine incl. páramo/puna). Ruin hash differs from the old expected value (predates this session). Earlier entries were dated 2026-09-27 by mistake; corrected to 2026-09-26.

## 2026-09-26 — Spec update: R6, Phases 6–11 (docs only, nothing built)
- Added Appendix R6 (simulation tiers and living-world rules), replaced Phases 6–8 with 6 Ecology core, 7 Living populations, 8 Disturbance and living water; old Camp life is now Phase 9 (plus culture), new Phase 10 Memory and lore, old Persistence is now Phase 11 (plus tick_region catch-up). Part F gained four checks.
- D3 gained: world.events, fauna.genome_mean, fauna.sex_ratio, soil.carcass, flora.burn_scar, terrain.water_level (seasonal), society[camp].culture, creature.memory[] (NEAR only). Owners inferred from the phase cards — designer to confirm.
- Cross-references renumbered: R4 inventory built in Phase 9; R5 out of scope until Phase 11.
- Still in Phase 0 (awaiting sign-off). Phase 1 ripple + Night Rider + Pond Crawler agents (started on the designer's "GO") are still working in their copies; not merged.

## 2026-09-26 — Phase 0 session 2 (commits 35fdd3a → a213f49) — awaiting sign-off
- Changed: spec R1 replaced + R1a palette added; DESIGN.md matches spec (45/20/35/20, 29.5-day moon). Merged: painted sky (ultramarine night, dense stars, big moon, day #1436FF→#4C7CFF, night fog #1E30C0), flat water (no reflections, no white net, seam line fixed, rivers now flow), R1a ground/stone/fire palette with firelight pool, 1/4 ordered dither, ultramarine haze. Postage-stamp planet (40 km, every band, 3.1 s) ON in data/dev.json; full planet via "postage_stamp": false.
- Verified: tools/p0_timelapse.gd PASS, tools/stamp_check.gd PASS, gl_compatibility no shader errors. Dusk river re-shoot on the full planet: /tmp/shots/p0final_river_{12.0,17.5,18.5,23.0}.png (sent to designer).
- Flagged too clean: day clouds (airbrushed banks), camp folk/fire props/mat (flat colour), far trunks and far hills (texture fades out), mid-distance grass (low-contrast grain), pyramid faces.
- Known misses: stone at night #000963 vs #3E4C8C (night contrast crushes it); folk by fire read red not orange; moonlit snow a little blue/dim; dusk clouds hot pink across upper sky; weak waterfall crests; foliage near-black at night in Compatibility renderer.
- Next: designer sign-off on the dusk river shot, or corrections. Then Phase 1.
- Open: stamp size 40 km? ruins/mythicals on the stamp? band grouping (alpine incl. páramo/puna)? pink dusk clouds OK? warmer #FFA050 fire so folk read orange? ruin hash differs from the old expected value (predates this session's work).

## 2026-09-26 — Phase 0 session 1 (commits a87aee8, 922916b)
- Changed: post grade (dither/black crush out; slight color bleed, cool haze, faint grain; night tint kept), all world textures linear + mipmaps, 3D render scale 0.8. Day split 45/20/35/20 (day/dusk/night/dawn) with smooth sky speed, eased weather-driven light, sun→moon cloud-light crossfade, 29.5-day moon with the mansion following it. Earlier (1993da5, merged before the spec): vertex-lit Lambert, flat ambient, no glow/SSAO/SSR/shadow maps, blob shadows.
- Dev: data/dev.json (20-min day, seed 42, first camp), F3 debug overlay, tools/p0_timelapse.gd (PASS: no frame-to-frame jumps).
- Verified: time-lapse sheet + curves; river-bank shots at 12:00/17:30/18:30/19:30/23:00. Dusk shot NOT yet GameCube-disc quality: water still reflects the sky (pink swirls) and glows neon at night; cloud layers look smeared, not painted.
- Held: set pieces on local branch hold/set-pieces (spec: no new ruins). Painted skybox + flat bright water exist in stopped agent copies (both matched R1 in audit) — designer to decide whether to finish them. Carved stone + old sky: discard.
- Next: fix water (no reflections, softer night glow) and sky/clouds (painted), then re-shoot dusk by the river for sign-off.
- Open: 45/20/35/20 order confirmed? dev day also speeds weather 6x; DESIGN.md still says 15/50/15/40 + 28-day moon; postage-stamp planet not built.

## 2026-09-26 — Spec v3 adopted (aligned to commit fe6ee3e)
- Current phase: **Phase 0 — Look & Light**
- Last sign-off: none yet
- Agents in copies: restyle, set-piece — audit against Appendix R1 before merging
- Next: send Phase 0 Prompt A (spec Part C), get the audit, then "Go."
- Open questions: 51 biomes in data vs 52 in design (resolve in Phase 2)
