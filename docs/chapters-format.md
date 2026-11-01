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
  {"id": "uh-oh", "number": 4, "title": "Uh oh", "dropped": true, "segments": []}
]}
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
any other keys the scene needs. Unknown keys are passed through untouched.

## Per-kid differences: `jack` and `becca` blocks

A segment (in `chapters.json` or in its data file) is a common block with optional `jack` and
`becca` blocks. For the current kid, the player lays that kid's block over the common keys
(shallow: a key in the kid block replaces the whole common value, nested dictionaries are not
merged). The other kid's block is dropped.

```json
{"kind": "scene", "scene": "res://scenes/engines/match.tscn", "choices": 4, "key": "number",
 "becca": {"choices": 3, "key": "color"}}
```

Becca gets `{"kind": "scene", "scene": ..., "choices": 3, "key": "color"}`.

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

Per-kid clips use the placeholder (`"name": "{kid}-airport"`) or a kid block
(`"jack": {"name": "jack-car"}`).

## The contract for a segment scene

`Game` (autoload, `scripts/game.gd`):

```gdscript
var segment: Dictionary          # this segment's data, merged for Game.kid
signal segment_finished
var last_segment_done := false
func segment_done() -> void      # call once when the segment is finished
```

A segment scene:

- reads its settings from `Game.segment` in `_ready()` (never branches on `Game.kid.id`);
- calls `Game.segment_done()` exactly once when the kid has finished (the payoff or the Continue
  button). It sets `last_segment_done = true`, emits `segment_finished`, and moves the player on;
- may offer Home (`Game.goto(Game.TITLE)`) and Replay (`Game.goto(<its own scene>)`, which
  keeps `Game.segment`);
- has no failure state: wrong moves wiggle and slide back.

Voice: `Voice.say(line_id, Game.sibling(), wait)`. Sounds: `Sfx.play(name)`. Glows:
`Glows.show_rects()`. Engines live in `scenes/engines/<name>.tscn` + `scripts/engines/<name>.gd`.

## The player (`Game`)

| Call | Does |
| --- | --- |
| `Game.chapters()` | The chapter list (Array of Dictionary), dropped ones included. |
| `Game.chapter(id)` | One chapter's Dictionary, or `{}`. |
| `Game.play_chapter(id)` | Starts a chapter at its first segment. |
| `Game.segment_done()` | Next segment; after the last, `Progress.mark_chapter_done(kid, id)`, then the map or the next chapter (`after`). |
| `Game.stop_chapter()` | Forgets the running chapter (tests call it when they finish). |

Clip and still segments run in `Game.INTRO`; scene segments change to their `scene`. Scene changes
go through `Game.goto()`, so with `Game.navigate = false` nothing changes scene and the request
lands in `Game.last_scene_request`. If no chapter is running, `segment_done()` only sets the flag
and emits the signal.

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
	game.last_segment_done = false
	var scene: Node = load("res://scenes/engines/match.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	# ... real input: Input.parse_input_event() taps and drags, as in tests/test_maze.gd ...
	t.check(game.last_segment_done, "finished")
	scene.free()
```

Use a temp `Progress.path` (see `tests/test_map.gd`) if the scene saves progress, and set it back
to `user://progress.json` at the end.

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
| `start_line` | `""` | Voice line id said at the start. `start_sound`: an `Sfx` name played at the start. |
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
