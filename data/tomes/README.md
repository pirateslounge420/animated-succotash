# Tome texts (design 3 Oct §DL)

One plain UTF-8 text file per tome, named in `data/tomes.json` → `tomes[].text_file`.
The game reads it with `scripts/player/tomes.gd` (`Tomes.book`) and shows it in the
tome panel (`scripts/ui/tome_panel.gd`, R to read a tome you carry).

## Format

```
The Book of Changes
---
1. Khien
The first page's text. Any number of lines; blank lines are kept inside a page.
---
2. Khwăn
The second page's text.
```

- **Line 1** is the tome's title (its title page).
- **Pages** are separated by a line holding only `---`.
- **A page's first line** is its heading (for the I Ching, the hexagram's number and name);
  the rest of the page is its text. The panel wraps long lines to its width.
- Blank lines round a page are trimmed. An empty page is skipped.

## Rules

- **Public-domain translations only.** The I Ching is James Legge's, *The Sacred Books of the
  East* vol. 16 (Oxford, 1882). Never Richard Wilhelm's in Cary F. Baynes's English (1950).
- One hexagram a page for the I Ching (64 pages); one chapter a page for the Tao (81).
- Set the tome's `filled` to `true` in `data/tomes.json` only when the whole text is in and
  checked against the source. Until then the tome never lies anywhere in the world (no blank
  books), and the dev overlay (F3) says `tome text missing: <id>`.
- Filling `iching_legge.txt` is a data job for Claude (chat): one agent per group of
  hexagrams, each checked against the public-domain edition.

## Fragments (design 9 Oct §FM.5, queue 73)

- A tome with a `fragments` list in `data/tomes.json` is split: each fragment, `{"id",
  "pages": [first, last]}`, is a run of its pages and its own pickup. Pages are counted
  from 1, the first page after the title page, in this file's order (for the I Ching,
  page n is hexagram n). The I Ching's four: 1–15, 16–30, 31–47, 48–64.
- In Torchfire 1's crawler the fragments lie on a dungeon's bottom floor (`TomePages`),
  **before the text is in too**: the "no blank books" rule above is for a tome found
  whole. A split tome whose text isn't in opens at its title page only, which says how
  much of it you hold ("pages 1 to 15 of 64"; the 64 is then the furthest page its
  fragments name). Once the text is in, the pages you hold read as any tome's, and the
  count comes from the text.
- Keep the fragments' ranges within the text's pages: a range past its last page is cut
  to it.
