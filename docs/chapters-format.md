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
(`light_up_route()`), holds a moment, and goes on (chapter 14's finale).

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
