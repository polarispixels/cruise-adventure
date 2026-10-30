# Cruise Adventure v0.3 Implementation Plan: Pack the Whole Card

**Goal:** Four levels (one per card row) with the card as the level map, saved progress, and spoken helper lines.
**Spec:** `docs/superpowers/specs/2026-10-30-cruise-adventure-v0.3-design.md`. v0.2 conventions still apply (see `docs/superpowers/plans/2026-10-29-cruise-adventure-v0.2.md`, "Global Constraints").
**Execution:** multi-agent. Tasks A, B and C are self-contained and go to Sonnet agents in separate worktrees. Task D (the room and the level flow) is coupled to everything, so the lead does it. The lead merges, then one strong final review.

## Global constraints (in addition to v0.2's)
- Godot 4.7.2, GDScript only, mouse events only, every visual and sound a file in `assets/`. No `if kid.id == ...` branches; per-kid differences live in `KidProfile` or data files.
- Tests are headless: `tools/godot.sh --headless --script res://tests/run_tests.gd`. Run `tools/godot.sh --headless --import` first after adding a `class_name`, a new asset, or in a fresh worktree. The runner fails any test that logs an engine or script error (`push_error` included). Use `print`, not `push_warning`, for expected fallbacks.
- Never write under `/mnt/c/Users/rgris/Documents/ChatGPT` (read-only art source).
- Commits end with the attribution lines in the task brief.
- Card geometry (both cards, card pixels): column centers x = 201, 467, 733, 999. Icon center y per row = 386, 700, 1016, 1330. Checkbox center y per row = 530, 845, 1160, 1475.

## Levels (data, owned by D)
| level | items (card row) | search spot | roll |
| --- | --- | --- | --- |
| 0 | shirt, shorts, underwear, socks | drawer | yes (rounds = kid.outfits) |
| 1 | pajamas, swimsuit, hoodie, nice-outfit | drawer | yes (1 round) |
| 2 | sandals, hat, hairbrush, toothbrush | basket | no |
| 3 | buddy, book, tablet, special | toybox | no; hug before packing the buddy |

## Interfaces

### A: art import (Sonnet)
- Produces `assets/props/<kid>/<item>-card.png` and `<item>-alt-1..7.png` (hue +45°·k recolor, generator `recolor`) for the 12 new items: pajamas, swimsuit, hoodie, nice-outfit, sandals, hat, hairbrush, toothbrush, buddy, book, tablet, special. Also `assets/characters/<kid>/{hmm,hug}.png`.
- Manifest entries in `data/art_manifest.json`, all `"approved": false`.
- A contact sheet of every new item in all 8 colors, plus a report listing items whose recolor looks wrong or unrecognizable. **D marks those color-locked.**

### B: progress and the card map (Sonnet)
- Autoload `Progress` (`scripts/progress.gd`, extends Node). Saves JSON at `var path := "user://progress.json"`; tests point `path` at a temp file.
  - `levels_done(kid_id: String) -> Array[int]`
  - `mark_done(kid_id: String, level: int) -> void` (saves immediately)
  - `next_level(kid_id) -> int` (lowest level not done; 4 when all done)
  - `intro_seen(kid_id) -> bool`, `mark_intro_seen(kid_id) -> void`
  - `reset() -> void`
  - Corrupt or missing files load as empty progress, with no error.
- `Card` (`scripts/card.gd`) gains rows, staying backward compatible:
  - `highlight(index: int, row := 0)`, `stamp(index: int, row := 0)`
  - `highlight_row(row: int)` (glow pulses around the whole row; -1 hides it)
  - `stamp_row(row: int)` (a big check over the row, separate from item checks)
  - `row_rect(row: int) -> Rect2` (card pixels)
  - `clear()` clears both kinds of check.
- `Game` (`scripts/game.gd`) gains:
  - `const MAP := "res://scenes/map.tscn"`, `var level := 0`
  - `func play_level(n: int)`: sets `level`, then `goto(ROOM)`
  - `pick(kid_id)` goes to INTRO if `not Progress.intro_seen`, else MAP
  - Intro (`scripts/intro.gd`) leaves to MAP and calls `Progress.mark_intro_seen`.
- Map scene `scenes/map.tscn` / `scripts/map.gd`:
  - The player's card fills the visible height, centered, on a background of the kid's room dimmed with `assets/ui/dim.png`.
  - Done rows get `stamp_row`. The next row pulses (`highlight_row(Progress.next_level)`).
  - A tap inside a row that's done or next calls `Game.play_level(row)`. Taps on later rows do nothing.
  - A home button (assets/ui/home.png) at the top left goes to TITLE.
  - The helper kid (`Game.sibling()`) stands at the bottom right, as in the drawer view.
  - If all 4 rows are done, every row is stamped and any row is tappable.
  - Exposes `func row_point(row: int) -> Vector2` (global center of a row) for tests.
- Title: a long press (≥ 2 s) on the version stamp calls `Progress.reset()`.

### C: voices (Sonnet)
- `data/voice_lines.json`: `[{"id": "find-pajamas", "text": "Find your pajamas!", "text_by_kid": {"jack": ..., "becca": ...}?}, ...]`, the 32 lines from `docs/voice/voice-lines-v0.3.md`. `text_by_kid` keys are the **speaker**.
- `tools/import_voice.py`: for each speaker kid and line, if `ART_ROOT/Voice/<Jack-Jack|Becca>/<id>.(m4a|wav|mp3|ogg)` exists, it converts it to `assets/voice/<kid>/<id>.ogg` (ffmpeg container, mono, loudness-normalized). Otherwise it synthesizes a placeholder with Windows SAPI (`tools/make_voice.py`; Becca = female voice, Jack-Jack = male voice, rate 0). Idempotent. A `data/voice_manifest.json` records `recorded | placeholder` per file.
- Autoload `Voice` (`scripts/voice.gd`):
  - `say(line_id: String, speaker: KidProfile) -> void`: plays `assets/voice/<speaker.id>/<line_id>.ogg` and interrupts any line already playing. Missing file → `print` and return.
  - `stop()`, `is_speaking() -> bool`
  - `var last_line := ""`, `signal said(line_id: String)`
  - `var enabled := true` (tests may turn it off)
  - `found_line() -> String`: rotates found-1, found-2, found-3.

### D: levels and the room (lead)
- `KidProfile` gains `pose`-independent helpers as needed.
- `data/levels.json` holds the table above.
- `room.gd` reads `Game.level`: items, search spot, roll or not, rounds.
  - Search spots: drawer = the dresser (as in v0.2); basket/toybox = new floor props (placeholders until art round 3).
  - No-roll levels: found items land on the rug as Draggables; each is dragged into the suitcase. The buddy plays the player's `hug` pose first.
  - Card shows the level's row.
  - Finish → `Progress.mark_done` → done video → buttons (replay level / back to map).
- Voice calls on every step via `Voice.say(..., Game.sibling())`.
- Version 0.3.0 / version code 3.
