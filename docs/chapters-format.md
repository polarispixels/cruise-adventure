# Chapters format and the segment contract

How the game knows its chapters, how a chapter plays, and what a segment scene (an engine or a
chapter's own scene) must do. Engines and chapter builders code against this page.

## `data/chapters.json`

```json
{"chapters": [
  {"id": "car", "number": 7, "title": "To the car", "after": "next",
   "segments": [
     {"kind": "clip", "name": "car-intro", "once": true, "optional": true},
     {"kind": "scene", "scene": "res://scenes/trunk.tscn"}]},
  {"id": "uh-oh", "number": 4, "title": "Uh oh", "dropped": true, "segments": []}]}
```

Chapters are listed in play order. Chapter fields:

| Field | Meaning |
| --- | --- |
| `id` | Short unique id, lower case (`flight`, `island1`). Progress and map stops are keyed by it. |
| `number` | The chapter number from the game spec (12 is played twice: `island1` and `island2`). |
| `title` | Developer-facing name. Never shown as text the kid has to read. |
| `segments` | Array of segments, played in order. |
| `after` | `"map"` (default): the journey map follows the last segment. `"next"`: the next chapter starts. |
| `dropped` | `true` for chapters 4-6. The player and the map skip them. |
| `rows` | Chapters 2-3 only: the card rows the room plays (`[0]`, `[1, 2, 3]`). |

Segment fields, by `kind`:

| Kind | Fields |
| --- | --- |
| `clip` | `name`: media name (below). `once` (default false): skipped when the chapter is already done, so a replay goes straight to play. `optional` (default false): if neither the clip nor its still exists, skip the segment instead of showing the placeholder card. Only chapters 1-8 use `optional`. |
| `still` | `name`: shows `assets/stills/<name>.png` with a slow zoom. `seconds` (default 6). |
| `scene` | `scene`: the `res://` scene to run. `data` (optional): `res://data/chapters/<chapter id>/<segment>.json`. |

Every segment may also have an `id` (a short name, used on the placeholder card and in tests) and
any other keys the scene needs. Unknown keys are passed through untouched. JSON numbers arrive
as floats: read them with `int(Game.segment["choices"])`.

A chapter with an empty `segments` list is not built yet: it has no map stop, and starting it
just returns to the map without marking it done. The journey map itself can be a segment:
`{"kind": "scene", "scene": "res://scenes/map.tscn", "finale": true}` lights up the whole route
(`light_up_route()`), holds a moment, and goes on (chapter 14's finale). The map says nothing over the finale.
Its spoken line: "pick-a-row" until the card is packed, then `next-stop` once such a line exists
(else "all-packed"), and `beach-replay` once the beach is done (`Voice.has_line()` guards both).

## Per-kid differences: `jack` and `becca` blocks

A segment (in `chapters.json` or in its data file) is a common block with optional `jack` and
`becca` blocks. For the current kid, the player lays that kid's block over the common keys
(shallow: a key in the kid block replaces the whole common value, nested dictionaries are not
merged). The other kid's block is dropped.

```json
{"kind": "scene", "scene": "res://scenes/engines/match.tscn", "choices": 4, "key": "number",
 "becca": {"choices": 3, "key": "color"}}
```
Becca gets `choices` 3 and `key` "color"; Jack-Jack gets 4 and "number".

## How `Game.segment` is built

When the player starts segment `i` of chapter `c`, it sets `Game.segment` to:

1. the segment's entry from `chapters.json`, kid block laid over;
2. then, if it has `data`, the data file's top-level object (a Dictionary), kid block laid over,
   laid over step 1 (data file keys win);
3. `"chapter": <chapter id>` and `"index": i` added;
4. placeholders replaced in every string value, at any depth: `{kid}` becomes `jack` or `becca`,
   `{sibling}` the other kid, `{row}` the card row number 1-4 (room rows only).

`Game.merge_segment(entry, kid_id)` does steps 1, 2 and 4 for any entry; tests use it too.

## Media names

A clip or still segment's `name` (after placeholders) names both files:

- clip: `res://assets/video/<name>.ogv`
- still: `res://assets/stills/<name>.png` (854x480, decision D6)

`scenes/intro.tscn` plays it: the clip if it exists; else the still with a slow zoom (about 6 s);
else a plain placeholder card showing the segment's `id` or `name` (developer placeholder). A tap
skips any of the three. A missing clip never blocks a chapter.

A clip or still segment may have `"line": "<voice id>"`: the sibling says it when the picture ends
(or is skipped), and the chapter goes on once the line is over ("We landed!" over a still).

Per-kid clips: `"name": "{kid}-airport"`, or a kid block `"jack": {"name": "jack-car"}`.

## The contract for a segment scene

`Game` (autoload) has `var segment: Dictionary`, `signal segment_finished`,
`var last_segment_done := false` and `func segment_done() -> void`. A segment scene:

- reads its settings from `Game.segment` in `_ready()` (never branches on `Game.kid.id`);
- calls `Game.segment_done()` exactly once when the kid has finished (the payoff or the Continue
  button). It sets `last_segment_done = true`, emits `segment_finished`, and moves the player on;
- may offer Home (`Game.goto(Game.TITLE)`) and Replay (`Game.goto(<its own scene>)`, which
  keeps `Game.segment`);
- has no failure state: wrong moves wiggle and slide back.

Voice `Voice.say(line_id, Game.sibling(), wait)`, sounds `Sfx.play(name)`, glows `Glows.show_rects()`.
Engines live in `scenes/engines/<name>.tscn` + `scripts/engines/<name>.gd`.

## The player (`Game`)

| Call | Does |
| --- | --- |
| `Game.chapters()` | The chapter list (Array of Dictionary), dropped ones included. |
| `Game.chapter(id)` | One chapter's Dictionary, or `{}`. |
| `Game.play_chapter(id, from := 0)` | Starts a chapter at segment `from`. |
| `Game.playing()` | Whether a chapter is running. |
| `Game.segment_done()` | Next segment; after the last, `Progress.mark_chapter_done(kid, id)`, then the map or the next chapter (`after`). |
| `Game.stop_chapter()` | Forgets the running chapter (tests call it when they finish). |

Clip and still segments run in `Game.INTRO`; scene segments change to their `scene`. Scene changes
go through `Game.goto()`, so with `Game.navigate = false` nothing changes scene and the request
lands in `Game.last_scene_request`. If no chapter is running, `segment_done()` sets the flag,
emits the signal and goes to the map. While navigating for real, a second `segment_done()` in
the same frame (a double tap on Continue) is ignored.

Progress: `Progress.chapter_done(kid_id, chapter_id)` and `Progress.mark_chapter_done(kid_id,
chapter_id)`. The journey map has a stop per chapter from 7 on; a stop's icon is
`res://assets/map/stop-<chapter id>.png`.

## Testing a segment scene

```gdscript
func test_match_jack(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.stop_chapter()
	game.kid = load("res://data/jack.tres")
	game.segment = game.merge_segment(
		{"kind": "scene", "scene": "res://scenes/engines/match.tscn", "data": "res://data/chapters/flight/seat.json"}, "jack")
	game.last_segment_done = false  # merge_segment() doesn't add "chapter"/"index"
	var scene: Node = load("res://scenes/engines/match.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	# ... real input: Input.parse_input_event() taps and drags, as in tests/test_maze.gd ...
	t.check(game.last_segment_done, "finished")
	scene.free()
```

A test of a whole chapter calls `game.play_chapter(id)` and then `game.segment_done()` in
place of each scene, reading `last_scene_request` and `segment` after each step (see
`tests/test_game.gd`). Tests that swap the list with `Game.use_chapters(list)` restore it with
`Game.use_chapters([])`; `Game.stills_dir` can point at `res://tests/fixtures/`.

Use a temp `Progress.path` (see `tests/test_map.gd`) if the scene saves progress, and set it back
to `user://progress.json` at the end.

## Placeholder art

Every chapter lists the art it needs in `data/chapters/<chapter id>/art.json` (the journey map's
stop icons in `data/chapters/map-art.json`). `tools/make_chapter_placeholders.py` draws a stand-in
for each entry, so a chapter runs end to end before any real art exists:

```json
[
 {"file": "assets/flight/aisle.png", "canvas": [1672, 941], "kind": "background", "color": "#BFD8F2", "label": "plane aisle"},
 {"file": "assets/flight/overhead-bin.png", "canvas": [520, 260], "kind": "sprite", "color": "#C8CCD2", "shape": "rounded"},
 {"file": "assets/stills/flight-takeoff.png", "kind": "still", "label": "takeoff out the window"}
]
```

| Field | Meaning |
| --- | --- |
| `file` | The game path, `assets/<chapter>/<name>.png`. The art request uses exactly this name, so the real art replaces the placeholder with no code changes. |
| `kind` | `background` (1672x941, opaque), `still` (854x480, opaque, always `assets/stills/<clip name>.png`, decision D6), `sprite` (transparent) or `icon` (transparent; map stops are 200x200). |
| `canvas` | `[w, h]` in pixels. Fixed for backgrounds and stills (may be left out); for sprites and icons, the display size (below). |
| `color` | `#rrggbb`, the main color of the real thing. Default per kind. |
| `shape` | `rect`, `rounded`, `circle`, or a rough outline: `silhouette-person`, `-suitcase`, `-backpack`, `-plane`, `-ship`, `-car`, `-palm`, `-cloud`, `-star`. Default `rect` for backgrounds and stills, `rounded` otherwise. |
| `label` | Optional words printed under the file name. |

Each placeholder is a flat shape in its color, a dashed border (magenta on sprites, so it shows on
any scene) and its file name with the word PLACEHOLDER printed in the middle.

```bash
python3 tools/make_chapter_placeholders.py                     # every art.json and map-art.json
python3 tools/make_chapter_placeholders.py data/chapters/flight/art.json
python3 tools/make_chapter_placeholders.py --still flight-takeoff   # a clip's fallback still
tools/godot.sh --headless --import && python3 tools/set_import_modes.py && tools/godot.sh --headless --import
```

Each file drawn gets a `data/art_manifest.json` entry with `"generator": "placeholder"`,
`"source": "placeholder"`, `"approved": false` and the `spec` it came from. Re-running updates
the entries and never duplicates them. `tools/import_art.py` redraws them like any other entry.
When real art arrives, change that file's entry to a `copy` (with its `source`) and the
placeholder tool leaves it alone from then on. Unapproved entries are listed by
`tools/check_art_approved.py`: playtest builds run with placeholders; a tagged release refuses them.

### Display size (Technical Optimization Spec, T3)

Art is made and requested at the size it is shown, not larger:

- No image is stored larger than about **1.25 times its largest on-screen size** at the tablet's
  1280x800 screen. A sprite shown 300 px tall is at most about 375 px tall.
- Set a sprite's `canvas` to that size. The art request (Briefs agent) copies the same canvas, so
  ChatGPT delivers at display size; full-size masters stay in the art project and only the game
  copy is resized by the import.
- Backgrounds stay 1672x941 (the scene is cropped to the tablet's 16:10) and stills 854x480,
  the clip size.
- Existing character poses are not downscaled yet; Phase 3 decides that against the size report
  (`python3 tools/check_asset_budget.py`).

## Engines

Six reusable segment scenes in `scenes/engines/`. A chapter uses one by naming it as a segment's
`scene` and giving its settings in the segment (or its `data` file), with `jack` / `becca` blocks
for the per-kid differences. Becca's easier version is always just different data.

### Keys every engine reads (`scripts/engines/engine_base.gd`)

**Coordinates are background pixels.** Every engine draws a Stage the size of the background
(1672 x 941), scaled to cover the screen like the airport scenes. Every point (`[x, y]`) and rect
(`[x, y, w, h]`) in engine data is in those pixels. Keep anything the kid needs inside the 16:10
safe area, **x 100-1572** (all of y 0-941 shows).

| Key | Default | Meaning |
| --- | --- | --- |
| `background` | flat sky color | `res://` path, 1672 x 941, scaled to cover. |
| `player_feet` | none (Tap moments: `[700, 900]`) | Where the kid's `Character` stands. Absent: no kid on screen. |
| `helper_feet` | `[1480, 930]` (Maze: none) | Where the sibling stands. `null`: no sibling. Hints point from here. |
| `kid_scale` | `0.16` | Character size (as at security). `helper_mirrored` (default true) faces the sibling left. |
| `foreground`, `foreground_rect` | none, the whole stage | A picture drawn over the stage (and the characters), under the Home button: a window frame, a car interior edge. `foreground_rect` `[x, y, w, h]`. |
| `lines` | `[]` | `[{"y", "from_x", "to_x", "color", "width"}]` drawn across the stage under the characters (the height line). Defaults: the safe area's width, `#e03030`, 8. |
| `done_overlay`, `done_overlay_sound` | none | `{"texture", "pos", "size"}` (`pos` is its center) fades in when the segment is done (the seatbelt sign lights up), with an optional sound. |
| `helper_scale` | `kid_scale` | The sibling's size, when it differs from the kid's (the height sign). |
| `start_line` | `""` | Voice line id said at the start. `start_sound`: an `Sfx` name played at the start. |
| `start_sound_after_line` | `false` | `true`: `start_sound` waits until `start_line` has finished (otherwise both start together). |
| `after_sound_line` | `""` | Said when `start_sound` ends. The music dips under the start sound as under a voice line. `intro_done` (and the `intro_finished` signal) follow when the start line, start sound and this line are all over. |
| `done_line` | `""` | Said at the end (waits for the line before it). `done_sound`: an `Sfx` name. |
| `done_delay` | `1.6` | Seconds of cheering between finishing and `Game.segment_done()`. Tests use `0`. |
| `hint_delay` | `Game.kid.hint_delay` (6 Becca, 8 Jack-Jack) | Seconds without a touch before the idle hint; it repeats every `hint_delay`. |
| `hint_line` | `""` (Maze: `this-way`) | Said with each idle hint. |
| `music` | none | A `res://assets/music/*.ogg` to play during the segment (the theme comes back after). |

Line keys take ids from `data/voice_lines.json`; the special id `"found"` rotates found-1/2/3. An
unknown id or a missing file is silent, never a crash. A missing texture draws a flat placeholder.
Every engine has the Home button top left and calls `Game.segment_done()` exactly once.

### Match (`res://scenes/engines/match.tscn`)

The target shows at the top; the kid taps the matching choice. Wrong: wiggle (and `wrong_line`).
After two misses, or the idle delay, the sibling points and the right choice pulses.

| Key | Default | Meaning |
| --- | --- | --- |
| `key` | `picture` | `picture` (the target shows the right choice's texture), `color` (a sticker dot of the choice's `color`), `number` (the choice's `label` as a big digit). |
| `choices` | | `[{id, texture, label, color, match, pos, height}]`. `label`: a digit drawn on the choice (door, row, floor). `color`: a sticker dot (`"#ff7eb9"`). `match`: a group name, so several choices can match one target (shells). |
| `target` / `rounds` | first choice | One target (a choice id or `match` group), or a list of them played in turn. A round may be a dict `{target, texture, label, color, line}`. |
| `count` | all | Show this many choices: every round's targets plus the first decoys. |
| `layout` | `row` | `row` (across the safe area at `row_y`), `grid` (`columns`, `grid_rect`), `doors` (a hallway `door_spacing` apart at `row_y`, wider than the screen; dragging scrolls it, a tap picks; also right for an aisle of seat rows), or per-choice `pos`. |
| `choice_height` | `220` | Choice height; a choice wider than its place shrinks to fit. |
| `target_pos`, `target_height`, `target_texture` | `[836, 150]`, `200`, none | Where the target shows; `target_texture` is a card behind the sticker or number (boarding pass, key card). |
| `label_at`, `label_size` | `[0, 0]`, `0.32 x` the choice height | Where a choice's `label` sits, as `[dx, dy]` from its texture center in background pixels, and its font size. A choice may set its own. |
| `overlay`, `overlay_scale` (per choice) | none, `0.5` | A picture drawn centered on the choice (a face on a key card), `overlay_scale` x the choice height. `overlay_scale` may also be set for all choices. |
| `target_overlay`, `target_label` (per round, or for all) | none | The same face and number on the target card, centered and at `label_at` / `label_size` scaled to the target's height. |
| `shuffle`, `seed` | `false` | Shuffle the choices (fixed by `seed`). |
| `right_line`, `wrong_line`, `round_line` | `found`, `""`, `""` | Lines. `right_sound` (`tag-snap`), `wrong_sound` (none). `round_delay` (0.6 s) between rounds. |

```json
{"kind": "scene", "scene": "res://scenes/engines/match.tscn", "background": "res://assets/flight/aisle.png",
 "start_line": "find-our-seat", "done_line": "we-sit", "layout": "doors", "door_spacing": 520, "row_y": 560,
 "player_feet": [260, 920],
 "jack": {"key": "number", "target": "row-12", "target_texture": "res://assets/flight/boarding-pass.png",
   "choices": [{"id": "row-10", "texture": "res://assets/flight/seat-row.png", "label": "10"},
               {"id": "row-11", "texture": "res://assets/flight/seat-row.png", "label": "11"},
               {"id": "row-12", "texture": "res://assets/flight/seat-row.png", "label": "12"},
               {"id": "row-13", "texture": "res://assets/flight/seat-row.png", "label": "13"}]},
 "becca": {"key": "color", "layout": "row", "target": "pink",
   "choices": [{"id": "blue", "texture": "res://assets/flight/seat-row.png", "color": "#3a7bd5"},
               {"id": "pink", "texture": "res://assets/flight/seat-row.png", "color": "#ff7eb9"},
               {"id": "yellow", "texture": "res://assets/flight/seat-row.png", "color": "#ffd23f"}]}}
```

Shells: `"choices": [{"id": "s1", "match": "shell", "texture": ...}, ..., {"id": "rock", ...}], "layout": "grid", "becca": {"rounds": ["shell", "shell", "shell"]}, "jack": {"rounds": ["shell", "shell", "shell", "shell", "shell"]}`.

### Place (`res://scenes/engines/place.tscn`)

The kid drags things to slots. While a thing is held, the free slots that take it glow. On a slot
that takes it: it snaps in (shrinking to fit); on another slot: wiggles and slides back; elsewhere:
slides back. A tap sends a thing to the next slot that takes it.

| Key | Default | Meaning |
| --- | --- | --- |
| `items` | | `[{id, texture, pos, height, slot, reusable, place_texture, mark_texture, hide_on_place}]`. `slot`: the slot id it goes in. `reusable`: a tool (sunscreen) that returns home after each drop and marks the slot instead. `place_texture`: the picture once placed (a buckled belt). `pos` absent: a row at `tray_y` (830). `height` default `item_height` (150). |
| `slots` | | `[{id, rect: [x, y, w, h] or point: [x, y] + size, accepts, texture, fill_texture, shrink, sound, line}]`. `accepts`: a list of item ids or `"any"` (default `"any"` when no item names a slot). `texture`: drawn under the slot (an outline). `fill_texture`: shown once filled. `shrink` (true): the item shrinks to the slot. |
| `ordered` | `false` | Slots fill in listed order. |
| `always_glow` | `false` | Glow every free slot even when nothing is held (sunscreen spots). |
| `tap_places` | `true` | A tap places a thing in its next slot. |
| `place_line`, `wrong_line` | `found`, `""` | `place_sound`: `tag-snap`. |

A slot with `"inert": true` is only a picture (its `texture`, at its `rect`): it takes nothing, never glows and is never a drop target (the castle outline, pieces already built).

Swimsuit on: slot `texture` the kid, `fill_texture` the kid in the swimsuit, slot
`hide_marker_on_fill: true` (the slot's own `texture` disappears as the fill shows; without it,
the fill is drawn over it), and the item's `hide_on_place: true` puts the swimsuit away. An item's
`appears_after: "<slot id>"` keeps it hidden (and untouchable) until that slot is filled.

Done when every non-reusable thing is placed, and with a reusable thing, every slot is filled.

```json
{"kind": "scene", "scene": "res://scenes/engines/place.tscn", "background": "res://assets/island/beach.png",
 "start_line": "sun-safe", "always_glow": true, "player_feet": [836, 900],
 "items": [{"id": "sunscreen", "texture": "res://assets/island/sunscreen.png", "reusable": true, "pos": [300, 820],
            "mark_texture": "res://assets/island/sunscreen-dab.png"}],
 "slots": [{"id": "nose", "point": [836, 400], "size": 90}, {"id": "arm-l", "point": [760, 600], "size": 90},
           {"id": "arm-r", "point": [912, 600], "size": 90}, {"id": "leg-l", "point": [800, 800], "size": 90},
           {"id": "leg-r", "point": [872, 800], "size": 90}],
 "becca": {"slots": [{"id": "nose", "point": [836, 400], "size": 110}, {"id": "arm-l", "point": [760, 600], "size": 110},
           {"id": "arm-r", "point": [912, 600], "size": 110}]}}
```

### Fit (`res://scenes/engines/fit.tscn`)

The trunk puzzle on any grid (`TrunkModel.from_dict`). Drag pieces in; a tap on a waiting piece
turns it; a piece snaps where it fits and slides back where it doesn't. While a piece is held, a
spot where it can go (so the grid still fills) glows. Done when the grid is full.

| Key | Default | Meaning |
| --- | --- | --- |
| `grid` | | `[cols, rows]`. |
| `blocked` | `[]` | Cells nothing can cover (wheel wells): `[[x, y], ...]`. |
| `pieces` | | `[{id, size: [w, h], texture, pos, rotated}]`. `size` standing; `rotated: true` starts turned; `pos` where it waits (absent: rows along the bottom). Texture default `res://assets/car/bag-<id>.png`. |
| `solution` | solved | `{id: {"cell": [x, y], "turned": bool}}`. Where `preplaced` and ghosts go. Absent: the solver finds one. |
| `preplaced` | `[]` | Piece ids that start in place (at the solution) and can't move. |
| `outlines` | `false` | A faded ghost of each piece where it goes. |
| `auto_turn` | `false` | A piece that only fits turned turns itself when dropped. |
| `area` | `[436, 200, 800, 500]` | The grid's rect (cells stay square, centered). |
| `container_texture`, `container_rect` | none | The bin or trunk picture and where it's drawn. With `cargo_rect` (in the texture's own pixels, like `data/trunk.json`), the grid sits on that part of the picture instead of `area`. `full_texture`: swapped in when full (a closed bin). |
| `place_line`, `turn_line`, `wrong_line` | `it-fits`, `turn-it`, `try-another-spot` | `place_sound`: `tray-slide`. |

```json
{"kind": "scene", "scene": "res://scenes/engines/fit.tscn", "background": "res://assets/florida/rental-lot.png",
 "start_line": "load-car", "grid": [6, 6], "blocked": [[0, 5], [2, 5], [5, 5]],
 "container_texture": "res://assets/florida/minivan-open.png", "container_rect": [536, 20, 600, 480],
 "cargo_rect": [300, 380, 1400, 1000],
 "pieces": [{"id": "mommy-yellow", "size": [5, 2]}, {"id": "daddy-gray", "size": [2, 3]},
            {"id": "jack-suitcase", "size": [2, 2]}, {"id": "becca-suitcase", "size": [2, 2]},
            {"id": "daddy-backpack", "size": [2, 2]}, {"id": "jack-backpack", "size": [1, 2]},
            {"id": "becca-backpack", "size": [1, 2]}, {"id": "mommy-purse", "size": [1, 1]}],
 "becca": {"preplaced": ["mommy-yellow", "daddy-gray"], "outlines": true, "auto_turn": true}}
```

### Maze (`res://scenes/engines/maze.tscn`)

The kid drags their face token along open corridors; the sibling's token trails a cell behind.
Reaching a wrong goal says `wrong_line`; the right goal is done. The idle hint steps the sibling
token toward the way and, with `footprints`, shows the next three steps.

| Key | Default | Meaning |
| --- | --- | --- |
| `fixed_thin_walls` | `false` | `true`: `fixed` is a (2w+1) x (2h+1) grid; odd-indexed characters are the cells (`S`, `G`, `A`-`F`, arrows, `.`, `#` for a solid cell) and the characters between two cells are the wall between them (`#`, `|`, `-`, `+` closed, anything else open). A 13x7 text is a 6x3 maze with big cells. `MazeModel.from_rows(rows, goal, true)`. |
| `hold_input_until_intro` | `false` | Drags do nothing until the start line, start sound and `after_sound_line` have finished. |
| `fixed` | | Rows of text, one character per cell: `#` wall, `.` floor, `S` start, `G` the right goal, `A`-`F` other goals, `>` `<` `^` `v` floor with an arrow sign. |
| `goal` | `G` | Which goal letter is right (fixed layouts). |
| `generate` | | `{size: [w, h], braid, loops, max_turns, gates, seed}`: a fresh maze like the airport's; the goals are in the right column. |
| `goal_textures` | a star | `[right, wrong, wrong...]` pictures for the goals. |
| `footprints` | `false` | Footprint hints. `footprint_texture` default `res://assets/airport/footprints-hint.png`. |
| `decor` | `[]` | `[{texture, cell: [x, y], cells}]` placed; plain texture paths go in dead ends off the way. |
| `wall_color`, `floor_color` | `#7E9CAF`, none | Wall and floor colors. `arrow_texture`: a picture for the arrow signs (drawn pointing right). |
| `area` | `[130, 160, 1412, 740]` | Where the board fits. |
| `token_texture`, `sibling_token_texture` | `res://assets/airport/token-<kid>.png` | The tokens. |
| `wrong_line` | `not-this-one` | `step_sound`: `step`. |

```json
{"kind": "scene", "scene": "res://scenes/engines/maze.tscn", "background": "res://assets/ship/deck-floor.png",
 "start_line": "big-honk", "start_sound": "ship-horn", "done_line": "all-together",
 "fixed": ["S.>..#A",
           "#.##.#.",
           "#.>....",
           "####.#G"],
 "goal_textures": ["res://assets/ship/meeting-spot.png", "res://assets/ship/deck-chairs.png"],
 "becca": {"footprints": true}}
```

### Moving targets (`res://scenes/engines/moving.tscn`)

Things move past; the kid taps the right ones. A decoy only wiggles. Nothing is lost: the loop
brings a target back around, and a drifting one re-enters from the left. Done when every target is
tapped.

| Key | Default | Meaning |
| --- | --- | --- |
| `items` | | `[{id, texture, height, target, pos}]`. `target: true` marks a right one (or list them in `targets`). |
| `targets` | `[]` | Item ids to tap. |
| `path` | `loop` | `loop` (round an ellipse in `loop_rect`, far side drawn behind), `drift` (left to right on `lanes` y values, `spacing` apart, wrapping), `still` (at `pos`; water jets). |
| `loop_rect` | `[300, 380, 1072, 380]` | The loop. `track_texture` (+ `track_rect`): a carousel picture under it. |
| `speed` | `120` | Background pixels per second. Becca's data is slower. |
| `item_height` | `170` | |
| (drift spacing) | | Drifting things are spaced among themselves; things with a `pos` (jets) don't count. The hint points at an on-screen moving target, and at a still one only when no moving target is left. |
| `tap_effect`, `tap_effect_sound` | none | A picture shown for 0.4 s where a target is tapped (a water-jet spray; `tap_effect_height`, default `item_height`), and a sound with it. |
| `collect_point` | none | Where tapped targets go (in a row). Absent: they pop away. |
| `right_line`, `wrong_line` | `found`, `""` | `right_sound`: `tag-snap`; `wrong_sound`: none. |

```json
{"kind": "scene", "scene": "res://scenes/engines/moving.tscn", "background": "res://assets/florida/baggage-claim.png",
 "start_line": "spot-our-bags", "track_texture": "res://assets/florida/carousel.png", "collect_point": [300, 860],
 "items": [{"id": "jack-suitcase", "texture": "res://assets/car/bag-jack-suitcase.png"},
           {"id": "becca-suitcase", "texture": "res://assets/car/bag-becca-suitcase.png"},
           {"id": "mommy-yellow", "texture": "res://assets/car/bag-mommy-yellow.png"},
           {"id": "other-1", "texture": "res://assets/florida/bag-other-1.png"}],
 "jack": {"targets": ["jack-suitcase", "becca-suitcase", "mommy-yellow"], "speed": 160},
 "becca": {"targets": ["becca-suitcase"], "speed": 70}}
```

### Tap moments (`res://scenes/engines/moments.tscn`)

Something arrives (from `arrive_from` to `arrive_to`); any tap during or after the arrival
succeeds: the actor does the action, `success_line` is said, the next moment comes after `gap`.
No timing failure: an untapped moment waits, and every `hint_delay` the prompt is said again while
the thing pulses and the sibling points. Taps between moments do nothing.

| Key | Default | Meaning |
| --- | --- | --- |
| `moments` | `3` | How many. |
| `textures` | placeholder | The arriving thing's pictures, one per moment (cycled). `arrive_height` (300). |
| `arrive_from`, `arrive_to`, `leave_to`, `arrive_time` | `[1800, 700]`, `[1100, 700]`, `[-200, 700]`, `1.5` | The arrival. |
| `action` | `hop` | `hop` (up `hop_height`, 140, and down) or `ride` (along `ride_path` `[[x, y], ...]` in `ride_time`, 1.6 s). `action_pose`: `arms-up`. |
| `actor` | `player` | `player` or `helper` (the sibling does it while the kid watches). |
| `keep_thing` | `false` | The arrived thing stays after the tap instead of leaving and fading. |
| `ride_end_texture`, `ride_end_size`, `ride_end_sound` | none, `[300, 200]`, none | A burst (a splash) shown for 0.8 s at the last `ride_path` point when a ride ends. |
| `prompt_line`, `success_line` | `""`, `found` | `arrive_sound` (none), `success_sound` (`whoosh`). |

```json
{"kind": "scene", "scene": "res://scenes/engines/moments.tscn", "background": "res://assets/beach/shore.png",
 "start_line": "jump-the-waves", "prompt_line": "jump", "success_line": "whee", "done_line": "we-did-it",
 "textures": ["res://assets/beach/wave.png"], "action": "hop", "player_feet": [700, 900],
 "jack": {"moments": 3}, "becca": {"moments": 2}}
```

### Models

- `TrunkModel.from_dict(data)`: the Fit keys above (`grid`, `blocked`, `pieces`, `solution`); also
  `preplace(ids)` and `is_blocked(cell)`. `from_file()` still reads `data/trunk.json`.
- `MazeModel.from_rows(rows, right_goal)`: a fixed layout (walls, arrows, goals as `gates`,
  `correct`). `MazeModel.generate(...)` is unchanged.

### Testing an engine segment

`tests/engine_kit.gd` sets `Game.segment` for a kid (kid blocks merged as the player does), runs the
scene and sends real touches: `kit.make(t, scene_path, segment, kid_id, size)`, `kit.tap`,
`kit.drag`, `kit.drag_through`, `kit.on_screen`, `kit.finished(t)`. See `tests/test_engine_*.gd`.
Use `"done_delay": 0` and a long `hint_delay` in test data.
