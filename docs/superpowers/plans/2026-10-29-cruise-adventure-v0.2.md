# Cruise Adventure v0.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn v0.1's one-screen demo into Jack-Jack and Becca's packing game: a title screen where you pick a child, that child's intro video, and their room, where you open the suitcase, find four items in the drawer (2 choices for Becca, 4 for Jack-Jack), roll, pack, close and zip. Released as `v0.2.0` once Ryan approves the art.

**Architecture:** One `Game` autoload holds the chosen `KidProfile` (a data resource per child) and handles scene changes. The room is one scene configured by the profile, run by a small step machine. The Find game is an overlay (`DrawerView`) inside the room. Reusable components: `Character` (pose swapping with the feet as origin), `Draggable` (v0.1, extended with accept/reject), `Card` and `Zipper`. Art is pulled from Ryan's art project by a manifest-driven import script, which also generates the missing pieces (color variants, UI placeholders, voice line, video conversion).

**Tech Stack:** Godot 4.7.2 GDScript (headless tests in Docker via `tools/godot.sh`), Python 3 + Pillow (art import), ffmpeg in Docker (video/audio conversion), Windows SAPI via `powershell.exe` (placeholder voice), GitHub Actions (existing).

**Spec:** `docs/superpowers/specs/2026-10-29-cruise-adventure-v0.2-design.md` (approved). The v0.1 design and plan show the conventions this code follows. Art specs: `docs/art/v0.2-art-requests.md`.

## Global Constraints

- All v0.1 constraints still hold: Godot **4.7.2**, CI image pinned by digest, GDScript only, `gl_compatibility`, 1920 x 1080 `canvas_items`/`expand`, `window/handheld/orientation=4`, `emulate_mouse_from_touch=true`, **mouse events only** in game code, every visual and sound is a file in `assets/` (no `_draw`, no `ColorRect`/`Panel` art), version only in `application/config/version`, never commit keystores.
- Version **0.2.0**, Android `version/code=2`, the same package and keystore.
- **Nothing requires reading.** Instructions are pictures, motion or audio. No failure sounds, penalties, timers or red X's.
- Difficulty comes **only from `KidProfile` data**: Becca `choices=2`, `hint_delay=6.0`; Jack-Jack `choices=4`, `hint_delay=8.0`. No `if kid == "becca"` branches outside data.
- Card item order: `ITEMS := ["shirt", "shorts", "underwear", "socks"]` (card row 1).
- Art source (read-only, **never write there**): `/mnt/c/Users/rgris/Documents/ChatGPT/Kids Packing Video/` (env `ART_ROOT`, defaulting to that path).
- Character canvases are 1024 x 1536 with feet at (512, 1480). Suitcase canvases are 1536 x 1024. Items are 512 x 512. Backgrounds are 1672 x 941. Draw order for suitcases: `open-back -> packed items -> open-front`.
- `v0.2.0` is **not tagged** until Ryan approves the art. `tools/check_art_approved.py` enforces this in the release job.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Rapid or repeated taps during transitions** (double-tapping the suitcase, tapping the dresser while the drawer is animating, tapping the layup twice): each step runs once and nothing gets stuck. Test `test_double_taps_do_not_skip_steps` (Task 8).
2. **A drag released outside every zone in the drawer**, including off the drawer art: the item returns home and nothing counts. Test `test_drop_outside_returns_home` (Task 6).
3. **The hint timer during interaction:** the helper must not point while the child is mid-drag, and the idle timer restarts on any input. Test `test_hint_waits_for_idle` (Task 8).
4. **Replay from the finish fully resets:** no leftover checks, layup items, bundle or zipper progress. Test `test_replay_starts_clean` (Task 8).
5. **A video that's missing, fails, or ends:** the kid always reaches the room (tap-skip, `finished`, or no clip). Test `test_intro_always_reaches_room` (Task 2).

## File Map

| File | Responsibility |
| --- | --- |
| `data/art_manifest.json` | game path <- source path / generator, plus an `approved` flag |
| `tools/import_art.py` | copy from `ART_ROOT`, recolor variants, convert video, run generators |
| `tools/make_placeholders.py` | (extended) UI placeholders: replay, home, zipper-pull, card-glow, target-slot, dim |
| `tools/make_voice.py` | placeholder voice line via Windows SAPI, then encode to .ogg |
| `tools/check_art_approved.py` | exits 1 if any manifest entry isn't approved |
| `tools/layout_preview.py` | renders `data/room_layout.json` over the art to a PNG for visual checks |
| `data/jack.tres`, `data/becca.tres` | `KidProfile` per child |
| `data/room_layout.json` | room positions in background pixels |
| `scripts/kid_profile.gd` | `class_name KidProfile extends Resource` |
| `scripts/game.gd` | autoload `Game`: chosen kid and navigation |
| `scripts/character.gd`, `scenes/character.tscn` | pose-swapping character |
| `scripts/draggable.gd`, `scenes/item.tscn` | v0.1 draggable, extended (shirt.tscn renamed to item.tscn) |
| `scripts/card.gd`, `scenes/card.tscn` | picture card with glow and stamps |
| `scripts/drawer_view.gd`, `scenes/drawer_view.tscn` | the Find matching game |
| `scripts/zipper.gd`, `scenes/zipper.tscn` | drag-along-a-line zipper |
| `scripts/room.gd`, `scenes/room.tscn` | room step machine |
| `scripts/intro.gd`, `scenes/intro.tscn` | intro video player |
| `scripts/title.gd`, `scenes/title.tscn` | title screen (new main scene) |

Removed in Task 9: `scenes/main.tscn`, `scripts/main.gd`, `tests/test_main.gd`, and the v0.1-only art (`bedroom.png`, `bed.png`, `suitcase.png`, `slot.png`, `shirt.png`, `check.png`). `star.png`, `replay.png`, `icon.png` and `chime.ogg` stay.

---

### Task 1: Art import pipeline

**Files:**
- Create: `data/art_manifest.json`, `tools/import_art.py`, `tools/make_voice.py`, `tools/check_art_approved.py`, `tests/test_assets.gd`
- Modify: `tools/make_placeholders.py` (add UI placeholders; keep v0.1 functions until Task 9)
- Generated (committed): everything under `assets/` listed in the manifest

**Interfaces:**
- Produces this asset layout (`<kid>` is `jack` or `becca`):
  - `assets/backgrounds/<kid>-room.png`
  - `assets/characters/<kid>/{idle,wave-1,wave-2,cheer,clap,point}.png`
  - `assets/props/<kid>/{suitcase-open-back,suitcase-open-front,suitcase-closed,bundle}.png`
  - `assets/props/<kid>/<item>-{card,alt-1,alt-2,alt-3}.png` for each item in ITEMS
  - `assets/props/shared/{open-drawer,check-mark}.png`
  - `assets/cards/<kid>.png` (from `Production Docs/Video Card - Jack v0.2.png` and `Video Card - Rebecca v0.2.png`)
  - `assets/ui/{replay,home,zipper-pull,card-glow,target-slot,dim}.png`
  - `assets/audio/who-do-you-want.ogg`, plus the existing `chime.ogg`
  - `assets/video/becca-intro.ogv` (from `Videos/becca-pack.mp4`)
- Manifest entry shape: `{"game": "assets/...", "source": "Game Assets/...png" | null, "generator": "copy" | "recolor" | "placeholder" | "voice" | "video", "from": "<game path of the card item, recolor only>", "hue_shift": <degrees, recolor only>, "approved": false}`.
- Commands: `python3 tools/import_art.py` (idempotent) and `python3 tools/check_art_approved.py` (prints the unapproved game paths, exits 1 if any).

- [ ] **Step 1: Write the failing test `tests/test_assets.gd`.**
  - `test_manifest_files_load`: parse `res://data/art_manifest.json`; for every entry, `ResourceLoader.exists(game_path)` is true, and `load()` returns a `Texture2D` for .png, an `AudioStream` for .ogg and a `VideoStream` for .ogv.
  - `test_character_canvas`: every `assets/characters/*/*.png` texture has size `(1024, 1536)`.
  - `test_variants_match_card_size`: every `<item>-alt-N.png` has the same size as its `<item>-card.png`.

  The manifest lives in `data/`, not `tools/`, because `tools/` has a `.gdignore` and Godot can't read files there.
- [ ] **Step 2: Run the tests and confirm they fail.** Run `tools/godot.sh --headless --script res://tests/run_tests.gd`. Expected: `test_manifest_files_load` FAILS (the manifest is missing).
- [ ] **Step 3: Write `data/art_manifest.json`.** Map every delivered PROVISIONAL file (names as in `Game Assets/`, e.g. `Characters/Becca/Becca - cheer v0.1 - PROVISIONAL.png` -> `assets/characters/becca/cheer.png`, and `Props/Jack-Jack/Jack-Jack - shirt v0.1 - PROVISIONAL.png` -> `assets/props/jack/shirt-card.png`).
  - Recolor entries: `hue_shift` of 180 for `alt-1`, +55 for `alt-2`, -55 for `alt-3`.
  - Mark the two backgrounds `"approved": true` (the handoff says Ryan approved them). Everything else is `false`.
- [ ] **Step 4: Implement `tools/import_art.py`.** It handles each generator as follows:
  - **`copy`:** copy the source file byte for byte.
  - **`recolor`:** HSV-rotate the hue of the pixels that belong to the item's dominant fill. Find it as the most common opaque hue among pixels with saturation > 0.25 and value > 0.35; affect the pixels within ±25° of that hue. Leave outlines, whites and alpha untouched.
  - **`placeholder`:** call into `make_placeholders.py`.
  - **`voice`:** call `make_voice.py`.
  - **`video`:** `ffmpeg -i becca-pack.mp4 -vf scale=1280:720 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 4 becca-intro.ogv` in the `jrottenberg/ffmpeg:6.1-alpine` container (the same docker.exe/`wslpath` fallback as `make_chime.py`).

  Read `ART_ROOT` from the environment, with the default from Global Constraints.
- [ ] **Step 5: Add the placeholder functions to `tools/make_placeholders.py`.**
  - `replay.png` and `home.png`: 384 x 384, a green circle with a white arrow or house.
  - `zipper-pull.png`: 128 x 128, a dark tab with a hole.
  - `card-glow.png`: 260 x 230, a soft yellow rounded-rect glow with a transparent center.
  - `target-slot.png`: 320 x 320, a dashed white rounded square.
  - `dim.png`: 8 x 8, black at 60% alpha (stretched by scale).
- [ ] **Step 6: Implement `tools/make_voice.py`.** Use `powershell.exe -NoProfile -Command` with `System.Speech.Synthesis.SpeechSynthesizer`, rate 0, choosing a female voice if one is installed. It writes a WAV for "Who do you want to play as?" to a Windows temp path, then encodes it to `assets/audio/who-do-you-want.ogg` with the ffmpeg container.
- [ ] **Step 7: Implement `tools/check_art_approved.py`.**
- [ ] **Step 8: Import and test.** Run `python3 tools/import_art.py && tools/godot.sh --headless --import`, then the test runner. Expected: all tests PASS. `file assets/video/becca-intro.ogv` reports `Ogg data, Theora video`. `python3 tools/check_art_approved.py` exits 1 and lists the provisional entries (correct at this stage).
- [ ] **Step 9: Visual check of the variants.** Render a contact sheet of every `*-card` / `*-alt-*` set to the scratchpad and view it. alt-1 must read as clearly different from the card version for each item. If a recolor fails on an item (for example, white socks whose only color is the stripe), adjust that entry's `hue_shift` or skip-band and record the ruling.
- [ ] **Step 10: Commit** the tools, the manifest, `assets/` and the tests: `feat: art import pipeline with variants, placeholders, voice and video`.

### Task 2: KidProfile, Game autoload, intro video (early device check)

**Files:**
- Create: `scripts/kid_profile.gd`, `data/jack.tres`, `data/becca.tres`, `scripts/game.gd`, `scripts/intro.gd`, `scenes/intro.tscn`, `tests/test_game.gd`
- Modify: `project.godot` (`[autoload] Game="*res://scripts/game.gd"`), `export_presets.cfg` (`include_filter="data/*.json"` on both presets)

**Interfaces:**
- `class_name KidProfile extends Resource`, with:
  - `@export var id: String` (`"jack"` / `"becca"`)
  - `@export var ribbon_color: Color` (Jack `#2F6FE4`, Becca `#F25C9A`)
  - `@export var choices: int`
  - `@export var hint_delay: float`
  - `@export var intro_video: String` (Becca `res://assets/video/becca-intro.ogv`, Jack `""`)
  - `func character(pose: String) -> Texture2D`
  - `func prop(name: String) -> Texture2D` (`assets/props/<id>/<name>.png`)
  - `func room() -> Texture2D`
  - `func card() -> Texture2D`
  - `func distractors(item: String) -> Array[Texture2D]`: the first `choices - 1` of `alt-1, alt-2, alt-3`
- Autoload `Game` (extends Node):
  - `const TITLE := "res://scenes/title.tscn"`, `INTRO := "res://scenes/intro.tscn"`, `ROOM := "res://scenes/room.tscn"`
  - `var kid: KidProfile`
  - `var navigate := true` (tests set it false)
  - `var last_scene_request := ""`
  - `func pick(kid_id: String) -> void`: sets `kid`, then calls `goto(INTRO)`
  - `func sibling() -> KidProfile`
  - `func goto(path: String) -> void`: records `last_scene_request`; calls `change_scene_to_file` only if `navigate`
- `intro.gd`: on ready, if `Game.kid.intro_video == ""` call `Game.goto(Game.ROOM)` deferred; otherwise play it full screen in a `VideoStreamPlayer` sized to the viewport, keeping aspect. A tap (mouse button press) or `finished` calls `Game.goto(Game.ROOM)` **once**.

- [ ] **Step 1: Write the failing tests in `tests/test_game.gd`.** Every test sets `Game.navigate = false` and resets `Game.last_scene_request`.
  - `test_profiles_differ_only_in_data`: `load("res://data/becca.tres").choices == 2` and `hint_delay == 6.0`; Jack's are `4` and `8.0`. `becca.distractors("shirt").size() == 1` and `jack.distractors("shirt").size() == 3`.
  - `test_profile_textures_load`: for both kids, `character("cheer")`, `prop("suitcase-closed")`, `room()` and `card()` are non-null.
  - `test_pick_goes_to_intro`: `Game.pick("becca")` makes `Game.kid.id == "becca"`, `Game.sibling().id == "jack"` and `last_scene_request == Game.INTRO`.
  - `test_intro_always_reaches_room`: (a) with Jack (no video), instantiating `intro.tscn` and awaiting 2 frames gives `last_scene_request == Game.ROOM`. (b) With Becca, after 1 frame the player `is_playing()`; a real left-click via `Input.parse_input_event` (helper pattern from `tests/test_input.gd`) gives `ROOM`. (c) Becca again: emitting the player's `finished` signal gives `ROOM`, requested exactly once (count calls through a signal `Game.scene_requested(path)`; add it to `goto`).
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement** `kid_profile.gd`, the two `.tres` files, `game.gd` (with `signal scene_requested(path: String)`), `intro.gd`/`intro.tscn`, and the autoload and export filter changes.
- [ ] **Step 4: Run all tests.** Expected: all PASS.
- [ ] **Step 5: Device check of video (the design's early risk).** Temporarily set `run/main_scene="res://scenes/intro.tscn"` in a throwaway commit **on a branch** `spike/video-check`. Set `Game.kid` to Becca when it's null in `intro.gd` for this branch only. Push the branch and trigger the workflow with `gh workflow run build.yml --ref spike/video-check`, then download the APK artifact. Ask Ryan to sideload it on the Fire tablet and report whether the clip plays smoothly with sound.
  - **Don't wait** for the answer before starting Task 3.
  - If it stutters, re-encode at `scale=960:540 -q:v 5` and repeat.
  - Delete the branch afterwards. Record the outcome in the ledger.
- [ ] **Step 6: Commit** on main: `feat: kid profiles, game navigation and intro video`.

### Task 3: Character component

**Files:**
- Create: `scripts/character.gd`, `scenes/character.tscn`, `tests/test_character.gd`

**Interfaces:**
- `class_name Character extends Node2D`, with:
  - `@export var kid: KidProfile`
  - `@export var mirrored := false`
  - `@export var height_scale := 0.45`
  - `var pose: String`
  - `func set_pose(name: String) -> void`
  - `func wave() -> void`: wave-1, wave-2, wave-1, wave-2 at 0.18 s each, then idle
  - `func cheer() -> void`: cheer pose, a 40 px hop tween (in scaled units) up and down over 0.35 s, back to idle after 1.0 s
  - `func clap() -> void`: clap for 0.8 s with a small squash, then idle
  - `func point_at(global_target: Vector2) -> void`: the point pose, mirrored so the arm faces the target, held until `set_pose("idle")` or another action
  - `func hit_rect() -> Rect2`: global rect around the body, `Rect2(-260, -1180, 520, 1180)` in canvas-from-feet units, scaled
- The scene: root `Character` (Node2D, origin = feet) -> `Sprite` (Sprite2D, `centered=false`, `offset=Vector2(-512, -1480)`). The root's `scale` is `Vector2(±height_scale, height_scale)`, negative x when facing left.
- Every action kills the previous action's tween (same pattern as `main.gd` in v0.1).

- [ ] **Step 1: Write the failing tests in `tests/test_character.gd`.**
  - `test_feet_are_origin`: with a Becca character at position (300, 900), the sprite's global transform maps canvas point (512, 1480) to (300, 900) within 0.5 px.
  - `test_mirrored_flips`: with `mirrored = true`, `scale.x < 0` and the feet are unchanged.
  - `test_cheer_returns_to_idle`: after `cheer()`, `pose == "cheer"`; after awaiting 1.2 s, `pose == "idle"` and `position.y` is back where it started.
  - `test_point_faces_target`: an unmirrored character at x=500 pointing at x=100 ends with `scale.x < 0`; pointing at x=900, `scale.x > 0`.
  - `test_actions_interrupt_cleanly`: `cheer()` then immediately `wave()`. After awaiting 1.5 s, `pose == "idle"` and y is back at the start.
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement** `character.gd` and `character.tscn`.
- [ ] **Step 4: Run all tests.** Expected: all PASS.
- [ ] **Step 5: Commit:** `feat: pose-swapping character with feet origin`.

### Task 4: Draggable accept/reject and generic item scene

**Files:**
- Rename: `scenes/shirt.tscn` -> `scenes/item.tscn` (root renamed `Item`, `Sprite`/`Shadow` textures empty; `@export var texture: Texture2D` applied in `_ready`)
- Modify: `scripts/draggable.gd`, `tests/test_draggable.gd`, `tests/test_input.gd`, `scenes/main.tscn` (point at item.tscn with the shirt texture until Task 9)

**Interfaces:**
- New in `Draggable`:
  - `@export var texture: Texture2D`: sets both Sprite and Shadow
  - `@export var accept_drop := true`
  - `signal rejected(item: Draggable)`
  - `@export var home_scale := 1.0`: the rest scale used instead of `Vector2.ONE` everywhere, with lift = `home_scale * LIFT_SCALE`
- With `end_drag` inside the zone and `accept_drop == false`: emit `rejected`, play a wiggle (rotation ±8°, 3 times, 0.3 s), then return home over `RETURN_TIME`. The result is `false`, and `is_placed` stays false.

- [ ] **Step 1: Update the existing tests to use `item.tscn`** with `texture = load("res://assets/props/jack/shirt-card.png")` (this survives the Task 9 cleanup), then add:
  - `test_rejected_drop_returns_home`: with `accept_drop = false`, dropping in the zone gives `end_drag(...) == false`, `rejected` emitted once and `placed` never. After awaiting 0.8 s the item is home (within 1 px) and `rotation == 0`.
  - `test_home_scale_respected`: with `home_scale = 0.5`, `begin_drag` gives `scale == Vector2.ONE * 0.5 * LIFT_SCALE`, and after the return `scale == Vector2.ONE * 0.5`.
- [ ] **Step 2: Run the tests and confirm the new ones fail.**
- [ ] **Step 3: Implement** the changes in `draggable.gd`, the rename, and the `main.tscn` reference.
- [ ] **Step 4: Run all tests.** Expected: all PASS, including v0.1's level and input tests.
- [ ] **Step 5: Commit:** `feat: draggable accept/reject, rest scale and generic item scene`.

### Task 5: Card component

**Files:**
- Create: `scripts/card.gd`, `scenes/card.tscn`, `tests/test_card.gd`

**Interfaces:**
- `class_name Card extends Node2D`, with:
  - `@export var kid: KidProfile`
  - `const ICON_CENTERS := [Vector2(201, 385), Vector2(467, 385), Vector2(733, 385), Vector2(999, 385)]`
  - `const CHECKBOX_CENTERS := [Vector2(201, 530), Vector2(467, 530), Vector2(733, 530), Vector2(999, 530)]` (card pixels, from `Video cards v0.2 - verification.json`, row 1)
  - `func highlight(index: int) -> void`: moves `Glow` (card-glow.png) to the icon center and pulses it; `-1` hides it
  - `func stamp(index: int) -> void`: adds a `check-mark.png` sprite at the checkbox center, scale 0.2, with a 0→1.2→1 pop
  - `func clear() -> void`
  - `func stamped_count() -> int`
- The scene: root `Card` (Node2D, origin = the card's top-left, card pixels) -> `Sprite` (`centered=false`) -> `Glow` -> `Checks` (Node2D). The room scales the whole card.

- [ ] **Step 1: Verify the checkbox data for Becca.** Read `Video cards v0.2 - verification.json` for the Rebecca card. If her row-1 rects differ from Jack's, make `ICON_CENTERS`/`CHECKBOX_CENTERS` per-kid exports in `KidProfile` instead and note the ruling.
- [ ] **Step 2: Write the failing tests in `tests/test_card.gd`.**
  - `test_stamp_places_check_on_box`: after `stamp(2)`, `stamped_count() == 1` and the new check's position is `CHECKBOX_CENTERS[2]`.
  - `test_highlight_moves_glow`: after `highlight(1)`, Glow is visible at `ICON_CENTERS[1]`; after `highlight(-1)` it's hidden.
  - `test_clear_removes_checks`: stamp 0..3, then `clear()`, gives `stamped_count() == 0`.
- [ ] **Step 3: Run the tests and confirm they fail.**
- [ ] **Step 4: Implement** `card.gd` and `card.tscn`.
- [ ] **Step 5: Run all tests.** Expected: PASS.
- [ ] **Step 6: Commit:** `feat: picture card with highlight and check stamps`.

### Task 6: DrawerView (Find matching game)

**Files:**
- Create: `scripts/drawer_view.gd`, `scenes/drawer_view.tscn`, `tests/test_drawer_view.gd`

**Interfaces:**
- `class_name DrawerView extends Node2D` (world space, 1920 x 1080 design coordinates), with:
  - `signal found(item: String)`
  - `const TARGET_CENTER := Vector2(960, 210)`
  - `const ROW_Y := 700.0`
  - `const ROW_LEFT := 560.0`, `const ROW_RIGHT := 1360.0`
  - `const ITEM_SCALE := 0.45`
  - `const MISSES_BEFORE_HINT := 2`
  - `var wrong_count := 0`
  - `func open(kid: KidProfile, helper: KidProfile, item: String, rng_seed: int = -1) -> void`
  - `func close() -> void`
  - `func choices() -> Array[Draggable]`
  - `func correct_choice() -> Draggable`
- The scene: `Dim` (dim.png scaled to cover 4000 x 3000, centered) -> `Drawer` (open-drawer.png at (960, 660), scale 1.4) -> `Slot` (target-slot.png at TARGET_CENTER) -> `Target` (Sprite2D, the item-card texture at scale 0.5, alpha 0.55) -> `Items` (Node2D) -> `Helper` (Character at feet (1790, 1070), height_scale 0.2, mirrored).
- `open()` builds `kid.choices` items with `item.tscn`: the card texture plus `kid.distractors(item)`, shuffled with `RandomNumberGenerator` (seeded when `rng_seed >= 0`). They're spaced evenly between ROW_LEFT and ROW_RIGHT (one item centers at 960), with `home_scale = ITEM_SCALE`, `drop_zone` = the Slot's global rect, `snap_point = TARGET_CENTER`, and `accept_drop` true only for the correct one.
  - On `placed`, wait for the snap (`Draggable.SNAP_TIME + 0.15` s), then emit `found(item)`.
  - On `rejected`, increment `wrong_count`; at `MISSES_BEFORE_HINT`, call `Helper.point_at(correct_choice().global_position)`.

- [ ] **Step 1: Write the failing tests in `tests/test_drawer_view.gd`.** Use real `Draggable` calls (`begin_drag`/`drag_to`/`end_drag`), and one real-touch test with the helpers from `test_input.gd`.
  - `test_becca_gets_two_choices`: `open(becca, jack, "shirt", 1)` gives `choices().size() == 2`, exactly one accepts drops, and its texture is `becca.prop("shirt-card")`.
  - `test_jack_gets_four_choices`: 4 choices, all different textures.
  - `test_correct_match_emits_found`: drag `correct_choice()` to TARGET_CENTER; after awaiting 0.5 s, `found` was emitted once with `"shirt"`.
  - `test_wrong_match_wiggles_back`: drag a wrong choice to TARGET_CENTER, and `found` is not emitted; after 0.8 s it's home and `wrong_count == 1`.
  - `test_helper_points_after_two_misses`: two wrong drops give `Helper.pose == "point"`.
  - `test_drop_outside_returns_home` (Review Focus 2): drag the correct item to (100, 1000) and release; `found` is not emitted, it's home after 0.5 s, and `wrong_count == 0`.
  - `test_touch_match`: a real touch drag of the correct choice onto the target emits `found`.
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement** `drawer_view.gd` and `drawer_view.tscn`.
- [ ] **Step 4: Run all tests.** Expected: PASS.
- [ ] **Step 5: Commit:** `feat: drawer matching game with per-kid difficulty`.

### Task 7: Zipper component

**Files:**
- Create: `scripts/zipper.gd`, `scenes/zipper.tscn`, `tests/test_zipper.gd`

**Interfaces:**
- `class_name Zipper extends Node2D`, with:
  - `signal zipped`
  - `@export var start: Vector2`, `@export var end: Vector2` (local coordinates)
  - `const GRAB_RADIUS := 90.0`
  - `const DONE_AT := 0.95`
  - `var progress := 0.0`
  - `func reset() -> void`
  - `func begin(global_point: Vector2) -> bool`: true only within GRAB_RADIUS of the pull
  - `func drag(global_point: Vector2) -> void`: projects the point onto the segment, clamped to 0..1, and moves the `Pull` sprite
  - `func release() -> void`
- Emits `zipped` once, when progress first reaches DONE_AT; after that the pull snaps to the end and stops accepting input. `_unhandled_input` maps mouse events to begin/drag/release, the same way as `Draggable`.

- [ ] **Step 1: Measure the zipper line on `assets/props/jack/suitcase-closed.png`.** Find the canvas row between y 380 and 620 with the most near-black pixels between x 150 and 1400, and its left and right ends. Record `start`/`end` in suitcase canvas pixels in the ledger. The pink case shares the silhouette, so one pair serves both.
- [ ] **Step 2: Write the failing tests in `tests/test_zipper.gd`.**
  - `test_grab_only_near_pull`: `begin` far from the pull is false; at the pull it's true.
  - `test_drag_projects_onto_line`: dragging to a point 200 px above the segment's midpoint gives `progress` ≈ 0.5 (±0.02).
  - `test_zipped_emits_once_at_end`: dragging past the end gives `zipped` emitted once; dragging back and forth again doesn't emit again.
  - `test_partial_does_not_zip`: drag to 0.6 and release; `zipped` is not emitted and `progress` stays 0.6.
- [ ] **Step 3: Run the tests and confirm they fail.**
- [ ] **Step 4: Implement** `zipper.gd` and `zipper.tscn` (a `Pull` Sprite2D with zipper-pull.png).
- [ ] **Step 5: Run all tests.** Expected: PASS.
- [ ] **Step 6: Commit:** `feat: drag-along zipper`.

### Task 8: Room scene and the full packing flow

**Files:**
- Create: `data/room_layout.json`, `tools/layout_preview.py`, `scripts/room.gd`, `scenes/room.tscn`, `tests/test_room.gd`

**Interfaces:**
- `data/room_layout.json` holds background pixel coordinates (1672 x 941, origin top-left). These are the initial values; Step 6 tunes them:
  ```json
  {"player_feet": [470, 905], "helper_feet": [1270, 885], "character_scale": 0.45,
   "suitcase_center": [860, 680], "suitcase_scale": 0.42,
   "layup_center": [650, 870], "layup_item_scale": 0.25, "layup_step": [0, -14],
   "dresser_rect": [0, 280, 385, 410], "drawer_from": [190, 350], "drawer_scale": 0.38,
   "card_margin": 24, "card_scale": 0.22}
  ```
- `room.gd` (extends Node2D):
  - `enum Step { START, OPENED, FINDING, ROLL, PACK_BUNDLE, CLOSE, ZIP, DONE }`
  - `signal step_changed(step: Step)`
  - `var step: Step`
  - `var item_index := 0`
  - `func tap_suitcase() -> void`, `func tap_dresser() -> void`, `func tap_layup() -> void`
  - `func on_found(item: String) -> void`
  - `func replay() -> void` (`Game.goto(Game.ROOM)`), `func home() -> void` (`Game.goto(Game.TITLE)`)
  - `func cover_scale(view: Vector2, tex: Vector2) -> float`: `max(view.x / tex.x, view.y / tex.y)`
- Scene tree: `Camera2D` (960, 540) -> `Stage` (Node2D at (960, 540), scale = cover_scale of the visible rect over 1672 x 941; children positioned in background pixels minus (836, 470.5)):
  - `Background`
  - `Suitcase` (Node2D: `Back`, `Packed`, `Front`, `Closed`, and `Zipper` placed from the Task 7 numbers)
  - `Layup`
  - `Bundle` (Draggable, hidden)
  - `Player` (Character)
  - `Helper` (Character, mirrored)
  - `DrawerSlide` (open-drawer sprite)

  Then `Card` (world space, top-right inside the visible rect), `DrawerView` (hidden), `Finish` (Node2D with `ReplayButton` and `HomeButton` TextureButtons, `Stars`, hidden), and `Chime`.
- The step machine (each tap handler is ignored unless the step matches, and **busy** while its own tween runs, per Review Focus 1):
  - **START** + tap_suitcase: Closed hides and Back/Front show; the Card tweens up out of the suitcase to the top-right corner. Step becomes OPENED and the card highlights 0.
  - **OPENED** + tap_dresser: DrawerSlide slides out over 0.3 s, then `DrawerView.open(Game.kid, Game.sibling(), ITEMS[item_index])`. Step becomes FINDING.
  - **FINDING** + `found`: DrawerView closes; a sprite of the card item flies from screen center to the layup slot `layup_center + layup_step * item_index`. Then `Card.stamp(item_index)`, Chime, `Player.cheer()`, `Helper.clap()`, and `item_index += 1`. If items remain, highlight the next one and re-open the DrawerView after 1.0 s. Otherwise, after 0.6 s, step becomes ROLL and the layup pulses.
  - **ROLL** + tap_layup: the layup items tween together and fade; Bundle (`prop("bundle")`) appears at the layup with `drop_zone` = Back's interior rect (the open-back sprite's opaque rect shrunk 15%) and `snap_point` = the suitcase interior center. Step becomes PACK_BUNDLE.
  - **PACK_BUNDLE** + Bundle `placed`: reparent Bundle under `Suitcase/Packed`, cheer. Step becomes CLOSE.
  - **CLOSE** + tap_suitcase: Back/Packed/Front hide, Closed shows with a small bounce, and Zipper resets and shows. Step becomes ZIP.
  - **ZIP** + `zipped`: step becomes DONE. Both characters cheer, stars burst, Chime plays, and after 0.8 s Finish shows.
- Hint (Review Focus 3): `_idle` time counts up in `_process`, resets on **any** InputEvent and on every step change, and pauses while any Draggable or the Zipper is dragging. At `Game.kid.hint_delay` the Helper calls `point_at(...)` the current target: the suitcase, the dresser rect center, the layup or the zipper pull. In FINDING the DrawerView's own hint rules apply.

- [ ] **Step 1: Write the failing tests in `tests/test_room.gd`.** Set `Game.navigate = false`, `Game.kid = becca` (or jack where noted), then instantiate `room.tscn`. Use the real-input helpers for taps, and call `DrawerView.correct_choice()` drags for Find.
  - `test_open_suitcase_reveals_card`: tap the suitcase gives `step == OPENED`, Card visible and `Card.Glow` visible.
  - `test_full_flow_becca`: open, dresser, then 4 × (drag the correct choice and await 1.6 s). Expect `Card.stamped_count() == 4` and `step == ROLL`. Then tap the layup, drag Bundle onto the suitcase, tap the suitcase, and drag the zipper from start to end. Expect `step == DONE` and Finish visible after 1.0 s.
  - `test_full_flow_jack`: the same with Jack, where each DrawerView shows 4 choices.
  - `test_drawer_reopens_by_itself`: after the first found, await 1.3 s; `DrawerView.visible` with no dresser tap.
  - `test_double_taps_do_not_skip_steps` (Review Focus 1): two suitcase taps on consecutive frames give `step == OPENED` (not CLOSE). Two dresser taps while the slide runs make DrawerView open once (count via `open` calls or the item count).
  - `test_hint_waits_for_idle` (Review Focus 3): at OPENED, wait `hint_delay + 0.5` s and the Helper pose is `"point"`. In a fresh room, after `begin_drag` on an item in FINDING with no release for `hint_delay + 0.5` s, the room-level hint hasn't fired (Helper pose isn't `"point"`).
  - `test_replay_starts_clean` (Review Focus 4): complete the flow, press `ReplayButton` (emit `pressed`) and `last_scene_request == Game.ROOM`. A fresh instance has `stamped_count() == 0`, `step == START`, the Layup empty and Bundle hidden.
  - `test_home_goes_to_title`: `HomeButton.pressed` gives `last_scene_request == Game.TITLE`.
  - `test_background_covers_tall_screens`: `cover_scale(Vector2(1920, 1200), Vector2(1672, 941))` ≈ 1.2752, and for (1920, 1080) ≈ 1.1483.
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement** `room.gd` and `room.tscn`, reading the layout JSON with `FileAccess` + `JSON.parse_string`.
- [ ] **Step 4: Run all tests** (redirect the output to the workspace and read the tail). Expected: all PASS, with no `ERROR:` lines other than fontconfig.
- [ ] **Step 5: Implement `tools/layout_preview.py`.** It composites the background, both characters (idle; the helper mirrored), the open suitcase with the bundle, three layup items and the card at layout positions into `build/layout-<kid>.png`, plus a 16:10 crop guide.
- [ ] **Step 6: Tune the layout.** Run the preview for both kids, view the PNGs, and adjust `room_layout.json` until nothing overlaps badly, the characters' feet are on the floor/rug, the suitcase sits on the rug, and the layup is fully on screen at 16:10. Re-run the tests (the positions are data, so they should stay green). Commit the tuned JSON.
- [ ] **Step 7: Commit:** `feat: room packing flow with card, drawer, roll, pack and zip`.

### Task 9: Title screen, main scene switch, v0.1 level removal

**Files:**
- Create: `scripts/title.gd`, `scenes/title.tscn`, `tests/test_title.gd`
- Modify: `project.godot` (`run/main_scene="res://scenes/title.tscn"`), `tests/test_input.gd` (retarget to the title and room), `tools/make_placeholders.py` (drop the v0.1-only generators)
- Delete: `scenes/main.tscn`, `scripts/main.gd`, `tests/test_main.gd`, and the v0.1-only art listed in the File Map

**Interfaces:**
- `title.gd`:
  - `const WAVE_EVERY := 3.0`
  - two Characters, `Jack` (feet at bg (560, 905)) and `Becca` (feet at bg (1110, 905), mirrored), on Jack's room, using the same `Stage` cover setup as the room
  - a name `Label` under each kid (LabelSettings: font size 40, `font_color = kid.ribbon_color`, white outline 10). The names are decoration for grown-ups
  - the title Label and the question Label
  - a `Voice` AudioStreamPlayer (who-do-you-want.ogg) that plays on ready and again on any tap that misses both kids
  - kids take turns: `Jack.wave()`, then `Becca.wave()` `WAVE_EVERY` seconds apart
  - a tap inside a kid's `hit_rect()` makes that kid `cheer()`, then 0.6 s later `Game.pick(id)`, once only

- [ ] **Step 1: Write the failing tests in `tests/test_title.gd`** (real touch input).
  - `test_tap_becca_picks_becca`: touch at the center of Becca's `hit_rect()`; after 0.8 s, `Game.kid.id == "becca"` and `last_scene_request == Game.INTRO`.
  - `test_tap_jack_picks_jack`.
  - `test_tap_empty_space_replays_voice`: touch at (960, 100), and `Voice.playing` is true; no pick.
  - `test_double_tap_picks_once`: two taps on Jack within 0.1 s request INTRO exactly once (count `Game.scene_requested`).
  - `test_kids_take_turns_waving`: after `WAVE_EVERY + 0.3` s, at least one kid's pose has been `wave-1` or `wave-2` (record via a pose-changed signal, or sample every frame).
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement** the title, switch the main scene, delete the v0.1 level and its tests and art, and retarget `test_input.gd` to touch-drive the room (keep a floor-tap test and a lost-release test against a DrawerView item).
- [ ] **Step 4: Import, run all tests, export web.** Run `tools/godot.sh --headless --import`, then the runner; expected all PASS. Then `tools/godot.sh --headless --export-release "Web" build/web/index.html`; expected exit 0.
- [ ] **Step 5: Ryan's playtest.** Push to main, let CI deploy Pages and build the APK artifact, then ask Ryan to play both kids on the web and on the tablet (test APK from the workflow artifact). Fix reported issues as additional tasks.
- [ ] **Step 6: Commit:** `feat: title screen picks a child; v0.1 level removed`.

### Task 10: Release v0.2.0 (gated on Ryan's art approval)

**Files:**
- Modify: `project.godot` (`config/version="0.2.0"`), `export_presets.cfg` (`version/code=2`), `tests/test_smoke.gd` (expect `"0.2.0"`), `.github/workflows/build.yml` (release job: `python3 tools/check_art_approved.py` before `gh release create`), `CHANGELOG.md`, `README.md` (art import section and the approval flow)

- [ ] **Step 1: Write the failing test.** Change the smoke test's expected version to `"0.2.0"` and add `test_android_version_code`: parse `res://export_presets.cfg` with `ConfigFile` and check that `preset.1.options` `version/code == 2`. Run them and confirm both FAIL.
- [ ] **Step 2: Bump the versions.** Bump `config/version` and `version/code` and run the tests; expected PASS.
- [ ] **Step 3: Add the art gate step** to the release job (it already checks out). Verify locally: `python3 tools/check_art_approved.py` exits 1 while anything is provisional.
- [ ] **Step 4: Update the CHANGELOG and README.** Add a `## [0.2.0] - <date>` entry. In the README, document `ART_ROOT`, `python3 tools/import_art.py`, how to mark art approved in `data/art_manifest.json`, and that the release refuses provisional art.
- [ ] **Step 5: Commit and push** (`release: prepare v0.2.0`); CI is green on main.
- [ ] **Step 6: STOP for Ryan's art approval.** Show him the list from `check_art_approved.py`. When he approves (in chat or the art status file), set those entries to `"approved": true`, re-run the import if newer art arrived, commit, push, then `git tag v0.2.0 && git push origin v0.2.0`. Watch the run; expected: the release has `cruise-adventure-v0.2.0.apk`. Ryan installs it **over** v0.1 on the tablet, with no uninstall needed.
