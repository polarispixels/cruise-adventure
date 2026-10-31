# Trunk Puzzle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new scene where the child loads all eight family bags into the trunk of a black SUV (some must be turned), closes the hatch and watches the family drive off, reached from the card map once packing is done.

**Architecture:** A pure grid model (`TrunkModel`) owns the rules: sizes, turning, placement, "full", and a backtracking solver for hints. A new scene (`trunk.tscn` / `trunk.gd`) draws the driveway, SUV and bags, turns touches into model moves, and runs the chapter loop (voice, hints, hatch, payoff video, finish buttons). Bag sizes, the grid and the reference solution live in `data/trunk.json`; per-kid difficulty lives in `KidProfile`.

**Tech Stack:** Godot 4.7.2 GDScript, the headless test runner (`tests/run_tests.gd`), Python asset tools (`tools/import_art.py`, `tools/make_placeholders.py`, `tools/import_voice.py`).

**Spec:** `docs/superpowers/specs/2026-10-31-trunk-puzzle-design.md`

## Global Constraints

- The grid is **7 x 5**, with wheel wells blocked at cells **(0,4) and (6,4)**.
- Bag sizes (w x h, standing):
  - `mommy-yellow` 5x2
  - `daddy-gray` 2x3
  - `jack-suitcase` 2x2
  - `becca-suitcase` 2x2
  - `daddy-backpack` 2x2
  - `jack-backpack` 1x2
  - `becca-backpack` 1x2
  - `mommy-purse` 1x1
- Reference solution (cell = top-left; T = turned):
  - `mommy-yellow` (0,0)
  - `jack-suitcase` (5,0)
  - `daddy-gray` (0,2) T
  - `becca-suitcase` (3,2)
  - `daddy-backpack` (5,2)
  - `jack-backpack` (1,4) T
  - `becca-backpack` (3,4) T
  - `mommy-purse` (5,4)
- A bag keeps its turned state when it slides back or is dragged out. Tapping a bag in the trunk only wiggles it.
- Becca: `mommy-yellow` and `daddy-gray` start placed at their reference spots and are locked. She gets outlines and auto-turn on drop.
- Jack-Jack: no pre-placed bags, no outlines, no auto-turn.
- Voice line ids: `load-car`, `turn-it`, `try-another-spot`, `it-fits`, `close-trunk`, `lets-go`. The helper sibling speaks them, as in packing.
- No failure states, timers or reading. Mouse events only (touch arrives as emulated mouse).
- Videos: `res://assets/video/<kid>-car.ogv` (intro, first time only) and `res://assets/video/car-drive-off.ogv` (payoff). Each is skipped silently when missing.
- Progress: a separate per-kid flag (`car_done`). `Progress.LEVELS` stays 4.
- Art paths: `assets/car/bag-<id>.png` (art at 200 px per cell, filling the rectangle), `assets/car/suv-open.png`, `assets/car/suv-closed.png` (2000x1600, cargo rect x 300-1700, y 380-1380 in the stand-in; read it from `data/trunk.json`, so real art only changes data), `assets/car/driveway.png` (1672x941).
- Commits end with the session's attribution lines.

## Review Focus

1. **16:10 tablet and window resizes:** every bag, the SUV and the buttons stay on screen and don't overlap. Test: `test_layout_fits_16_10_and_16_9` (Task 4).
2. **A lost release (finger lifted off-screen, app loses focus) mid-drag:** the bag ends up either placed or back on the driveway, never stuck floating. Test: `test_lost_release_returns_the_bag` (Task 4).
3. **Taps during the payoff video or a double tap on the hatch:** the finish runs once; the video is skippable. Test: `test_hatch_double_tap_finishes_once` (Task 5).
4. **Dragging a locked bag (Becca):** it doesn't move. Test: `test_locked_bag_stays_put` (Task 4).
5. **A dead end:** bags placed so the rest can't fit. The hint wiggles a wrong bag, and dragging it out recovers. Test: `test_hint_flags_a_dead_end` (Task 2) and `test_drag_out_of_trunk` (Task 4).

---

### Task 1: Data, stand-in art and voice lines

**Files:**
- Create: `data/trunk.json`
- Modify:
  - `tools/make_placeholders.py` (add `car(name, dst)`)
  - `tools/import_art.py` (the placeholder generator calls `make_placeholders.car` for files under `assets/car/`)
  - `data/art_manifest.json` (11 entries, generator `placeholder`, `approved: false`)
  - `data/voice_lines.json` (6 lines)
  - `scripts/kid_profile.gd`, `data/jack.tres`, `data/becca.tres`
- Test: `tests/test_assets.gd` (existing manifest test covers loading); `tests/test_trunk_model.gd` is created in Task 2.

**Interfaces:**
- Produces:
  - `data/trunk.json`:
    ```
    {"cols":7, "rows":5, "blocked":[[0,4],[6,4]], "cell_px":200,
     "cargo_rect":[300,380,1400,1000],
     "bags":[{"id":"mommy-yellow","size":[5,2]}, ...],
     "solution":{"mommy-yellow":{"cell":[0,0],"turned":false}, ...}}
    ```
  - KidProfile exports: `trunk_preplaced: PackedStringArray`, `trunk_outlines: bool`, `trunk_auto_turn: bool`, and `func car_intro() -> String` returning `"res://assets/video/%s-car.ogv" % id`.
  - Becca: `["mommy-yellow","daddy-gray"]`, true, true. Jack-Jack: `[]`, false, false.

- [ ] **Step 1: Write the failing test.** In `tests/test_assets.gd`, add `test_car_art_matches_trunk_data`:
  - every bag in `data/trunk.json` has `res://assets/car/bag-<id>.png` sized `size * cell_px`;
  - `suv-open` and `suv-closed` are the same size;
  - `cargo_rect` size == `[cols*cell_px, rows*cell_px]`.
- [ ] **Step 2: Run it.** `tools/godot.sh --headless -s tests/run_tests.gd -- --only=test_assets`. Expected: FAIL (no trunk.json).
- [ ] **Step 3: Write `data/trunk.json`.** Use the Global Constraints values.
- [ ] **Step 4: Add `make_placeholders.car(name, dst)`.**
  - Bags: rounded rectangles in the owner's colors (yellow `#F2C230`, gray `#8A9099`, blue `#2F6FE4`, pink `#F07AB0`, black `#2A2A2A`), with a handle, outlined `OUTLINE`, filling their canvas minus 8 px.
  - Jack-Jack's backpack: gray and black with a small red truck shape.
  - SUV: a black body, taillights, tires, and a dark gray cargo rectangle at the data's cargo rect, with wheel-well bumps in its bottom corner cells. The open version has the hatch raised above it; the closed version has the hatch covering the cargo rect.
  - Driveway: sky, house front, a gray driveway.
- [ ] **Step 5: Wire it up and generate.**
  - Add the 11 manifest entries.
  - Route `assets/car/*` placeholders to `car()`.
  - Run `python3 tools/import_art.py` and `tools/godot.sh --headless --import`.
- [ ] **Step 6: Add the 6 voice lines.** Put them in `data/voice_lines.json`, with words from `docs/voice/voice-lines-v0.4.md`. Run `python3 tools/import_voice.py` (placeholder voices).
- [ ] **Step 7: Add the KidProfile fields and `car_intro()`.** Set the values in both `.tres` files.
- [ ] **Step 8: Run the full suite.** Expected: all pass, including the new test.
- [ ] **Step 9: Commit.** `feat: trunk data, stand-in car art and voice lines`

### Task 2: TrunkModel

**Files:**
- Create: `scripts/trunk_model.gd` (`class_name TrunkModel extends RefCounted`)
- Test: `tests/test_trunk_model.gd`

**Interfaces:**
- Consumes: `data/trunk.json` (Task 1).
- Produces:
  - `static func from_file(path := "res://data/trunk.json") -> TrunkModel`
  - `var cols: int`, `var rows: int`, `var bag_ids: Array[String]` (file order)
  - `func size_of(id: String, turned: bool) -> Vector2i`
  - `func is_turned(id: String) -> bool` and `func set_turned(id: String, turned: bool) -> void`. A bag's turned state lives in the model, whether it's placed or not.
  - `func can_place(id: String, cell: Vector2i) -> bool`: uses the bag's current turned state. False if any cell is outside, blocked or taken by another bag. The bag's own cells don't count as taken.
  - `func place(id: String, cell: Vector2i) -> bool` (`can_place`, then record), `func remove(id: String) -> void`, `func cell_of(id: String) -> Vector2i` (`Vector2i(-1, -1)` when not placed), `func placed_ids() -> Array[String]`
  - `func is_full() -> bool` (all bags placed)
  - `func solve(allow_turns := true) -> Dictionary`: `{id: {"cell": Vector2i, "turned": bool}}` for every bag, keeping the placed bags where they are, or `{}` if impossible.
  - `func reference_solution() -> Dictionary`: the solution from data, in the same shape (RefCounted already has reference()).
  - `func hint() -> Dictionary`:
    - `{}` when full;
    - `{"kind": "wrong", "id": <the first placed bag in bag_ids order whose removal makes solve() succeed>}` when solve() is empty;
    - else `{"kind": "next", "id", "cell", "turned"}` from solve(): the first unplaced bag (bag_ids order) whose solved `turned` differs from its current state, else the unplaced bag with the largest area.

- [ ] **Step 1: Write the failing tests:**
  - `test_sizes_turn`: yellow (5,2) standing and (2,5) turned.
  - `test_wheel_wells_and_edges_block`: purse can't go at (0,4) or (6,4); yellow can't go at (3,0).
  - `test_bags_cannot_overlap`.
  - `test_reference_solution_fills_the_trunk`: place all 8 per `reference()`, then `is_full()`.
  - `test_trunk_needs_a_turn`: from empty, `solve(false) == {}` and `solve(true).size() == 8`.
  - `test_solve_keeps_placed_bags`.
  - `test_hint_prefers_a_bag_that_must_turn`: from empty, the hint kind is "next" and the bag must turn per the returned solution.
  - `test_hint_flags_a_dead_end`: place the purse at (0,0); the hint is `{"kind":"wrong","id":"mommy-purse"}`.
  - `test_turned_state_survives_remove`.
- [ ] **Step 2: Run them.** `-- --only=test_trunk_model`. Expected: FAIL (TrunkModel undefined).
- [ ] **Step 3: Implement.** The solver fills the first empty open cell, trying each unplaced bag in both orientations, with backtracking. It runs on 33 cells and 8 bags.
- [ ] **Step 4: Run them.** Expected: 9 pass. Run the full suite.
- [ ] **Step 5: Commit.** `feat: trunk grid model with solver and hints`

### Task 3: Progress flag and the way in

**Files:**
- Modify:
  - `scripts/progress.gd` (`car_done(kid_id) -> bool`, `mark_car_done(kid_id)`)
  - `scripts/game.gd` (`const TRUNK := "res://scenes/trunk.tscn"`, `const CAR := 4`, `func play_car() -> void`)
  - `scripts/intro.gd` (when `Game.intro_level == Game.CAR`: play `kid.car_intro()`, then `goto(TRUNK)`)
  - `scenes/map.tscn`, `scripts/map.gd` (a `CarButton` TextureButton, visible only when `next_level >= LEVELS`, texture `res://assets/car/suv-closed.png`, at least 220 px tall, beside the card; pressed → `Game.play_car()`)
- Test: `tests/test_progress.gd`, `tests/test_game.gd`, `tests/test_map.gd`

**Interfaces:**
- Produces:
  - `Progress.car_done(kid_id: String) -> bool`, `Progress.mark_car_done(kid_id: String) -> void`
  - `Game.play_car()`: if the car isn't done and `ResourceLoader.exists(kid.car_intro())`, set `intro_level = CAR` and go to INTRO; else go to TRUNK.
  - `map.car_button_point() -> Vector2` for tests.

- [ ] **Step 1: Write the failing tests:**
  - `test_car_done_saved_and_reset` (progress)
  - `test_play_car_without_a_clip_goes_to_trunk` (no car clip is delivered yet: asserts TRUNK, and that `intro_level` stays -1)
  - `test_intro_for_car_goes_on_to_the_trunk` (set `Game.intro_level = Game.CAR` and run the intro scene with no clip: it requests TRUNK and resets `intro_level` to -1)
  - `test_car_button_only_when_card_done` (map: hidden with done=[0,1,2], visible with [0,1,2,3])
  - `test_tap_car_button_goes_to_trunk` (real tap)
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.** Add a minimal `scenes/trunk.tscn` (Node2D root with `scripts/trunk.gd`, empty `_ready`) so the path exists. Task 4 fills it in.
- [ ] **Step 4: Run the full suite.** Expected: pass.
- [ ] **Step 5: Commit.** `feat: car button on the finished card, car intro, car progress flag`

### Task 4: The trunk scene: dragging, turning, snapping

**Files:**
- Modify: `scenes/trunk.tscn`, `scripts/trunk.gd`
- Create: `scripts/bag.gd` (`class_name Bag extends Node2D`: a Sprite2D child, `id`, `locked`, `func set_turned(on: bool)` rotates the sprite 90° and swaps its rect, `func rect() -> Rect2` global, `func wiggle()`, `func glide_to(global_pos: Vector2)`)
- Test: `tests/test_trunk.gd`

**Interfaces:**
- Consumes: `TrunkModel` (Task 2), the KidProfile trunk fields (Task 1), `Game.kid`, `Game.sibling()`, `Voice.say(line, speaker)`.
- Produces (for Task 5 and tests):
  - in `trunk.gd`: `var model: TrunkModel`;
  - `func bag(id: String) -> Bag`;
  - `func cell_center(cell: Vector2i, size: Vector2i) -> Vector2` (global point where a bag of that size sits at that cell);
  - `func ground_point(id: String) -> Vector2`;
  - `signal filled`.

Scene layout (base 1920x1080, re-fit on `size_changed`):
- the driveway covers the screen;
- the SUV sits centered horizontally, scaled so one cell is `CELL := 100.0` px on screen;
- bags rest on the driveway at the same scale, in fixed ground slots to the left, right and below the car, each slot inside the visible rect;
- the helper sibling sits bottom-right;
- the home button sits top-left, as in the room.

Moves:
- **Press on a bag (not locked) and move more than `Draggable.TAP_DISTANCE`:** it's a drag. The bag follows the finger, lifted (scale 1.1, z on top). If it was in the trunk, `model.remove(id)` happens at lift.
- **Release:** the target cell is the cell nearest the bag's top-left corner (bag top-left global → cargo-local / CELL, rounded).
  - `model.place` succeeds → glide to `cell_center`, say a found cheer, check `is_full()`.
  - Fails, but would succeed turned → if `trunk_auto_turn`, turn it and place it; otherwise say `turn-it` and glide back to the ground.
  - Otherwise say `try-another-spot` and glide back.
- **Release without moving (a tap):** on the ground, toggle turned (in the model and the sprite). In the trunk, or locked, wiggle only.
- **Outlines (`trunk_outlines`):** draw each unplaced bag's reference spot as a faint white rounded rectangle, turned per the reference.
- **Lost release:** a new press while dragging, or app focus out, drops the bag where it is, using the release rules.

- [ ] **Step 1: Write the failing tests (real input via `Input.parse_input_event`, as in `test_room.gd`):**
  - `test_drag_into_trunk_places_bag` (jack: purse to (5,4))
  - `test_drop_that_does_not_fit_slides_back` (yellow onto (3,0); it ends at its ground point, unplaced)
  - `test_tap_on_ground_turns_bag`
  - `test_bag_that_needs_turning_says_turn_it` (jack: gray standing at (0,2) is rejected; Voice.last_line == "turn-it")
  - `test_becca_auto_turns` (becca: gray already placed; backpack standing dropped at (1,4) gets placed turned)
  - `test_turned_state_kept_after_slide_back`
  - `test_drag_out_of_trunk` (place, then drag back to the ground; it's unplaced)
  - `test_tap_in_trunk_only_wiggles`
  - `test_locked_bag_stays_put` (becca: dragging yellow doesn't move it)
  - `test_becca_starts_with_two_bags_in` and `test_jack_starts_empty`
  - `test_outlines_only_for_becca`
  - `test_lost_release_returns_the_bag`
  - `test_layout_fits_16_10_and_16_9` (for 1920x1080 and 1920x1200 windows: every bag's ground rect is inside the visible rect, no two ground rects overlap, and none overlaps the cargo rect)
- [ ] **Step 2: Run them.** `-- --only=test_trunk`. Expected: FAIL.
- [ ] **Step 3: Implement `bag.gd`, the scene and `trunk.gd`.**
- [ ] **Step 4: Run them, then the full suite.** Expected: all pass.
- [ ] **Step 5: Commit.** `feat: trunk puzzle scene - drag, turn, snap`

### Task 5: Hints, finishing, payoff and the finish buttons

**Files:**
- Modify: `scenes/trunk.tscn` (Hatch area, `PayoffVideo` CanvasLayer + VideoStreamPlayer, `Finish` with Home/Replay/Continue buttons copied from `room.tscn`), `scripts/trunk.gd`
- Test: `tests/test_trunk.gd`

**Interfaces:**
- Consumes: `model.hint()` (Task 2), `Progress.mark_car_done` (Task 3), `Music.hold`, `Voice`.
- Produces: `func hatch_point() -> Vector2` and `var finished: bool` for tests.

Behavior:
- **Start:** say `load-car`.
- **Idle for `Game.kid.hint_delay`:**
  - `hint().kind == "wrong"` → that bag wiggles, the helper points at it, say `try-another-spot`.
  - `"next"` → that bag pulses (as the room's pulse cue) and a glowing outline shows at the hinted cell and turn, the helper points at the bag, say `load-car`.
  - Any input resets the idle timer.
- **When full:** emit `filled` and say `close-trunk` (wait). The hatch pulses.
- **Tapping the hatch area** (the cargo rect) while full:
  1. swap to `suv-closed`, hide the bags;
  2. `Progress.mark_car_done`, say `lets-go` (wait);
  3. play `car-drive-off.ogv` if it exists (Music held, a tap skips);
  4. show Finish.
  It runs once.
- **Finish buttons:** Home → TITLE, Replay → TRUNK, Continue → MAP. There is an always-visible in-play home button, as in the room.

- [ ] **Step 1: Write the failing tests:**
  - `test_says_load_car_at_start`
  - `test_idle_hint_points_at_a_bag`
  - `test_idle_hint_flags_dead_end` (jack: purse at (0,0), then idle)
  - `test_filling_says_close_trunk` (place all 8 per the reference via real drags, or `model` + `_settle` helper)
  - `test_tap_hatch_closes_and_marks_done` (Finish visible after it, `Progress.car_done`)
  - `test_hatch_double_tap_finishes_once`
  - `test_finish_buttons_go_home_replay_continue`
  - `test_home_button_while_playing`
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them, then the full suite.** Expected: all pass.
- [ ] **Step 5: Commit.** `feat: trunk hints, hatch, payoff and finish`

### Task 6: Checkpoint build

**Files:**
- Modify: `docs/site/story.json` (Chapter 7 checks: "Build the trunk puzzle" `files: ["scenes/trunk.tscn"]`; art check `files` on `assets/car/suv-open.png` stays manual until real art, so label it "Art: car, open trunk, trunk-sized suitcases (stand-ins in)"), `CHANGELOG.md` (Unreleased: the trunk puzzle)

- [ ] **Step 1: Run the full Godot suite and the Python tests.** Expected: all pass.
- [ ] **Step 2: Export the web build.** `tools/godot.sh --headless --export-release "Web" build/web/index.html`, then play it at http://localhost:8060: finish the card (or use a saved progress), tap the car, and load the trunk as Jack-Jack and as Becca.
- [ ] **Step 3: Commit, push, then CI build and a playtest pre-release.** `playtest-v0.4-5` on branch v0.4.
- [ ] **Step 4: Hand over for the checkpoint.** Give Ryan the APK and browser links.
