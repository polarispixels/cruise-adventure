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
