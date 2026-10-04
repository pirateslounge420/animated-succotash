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
