# Cruise Adventure v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a one-screen Godot game (drag the shirt into the suitcase) through GitHub Actions to GitHub Pages and a signed APK on a GitHub Release tagged `v0.1.0`.

**Architecture:** A Godot 4.7.2 GDScript project, written entirely as text (Ryan never opens the editor). All Godot commands run inside the `barichello/godot-ci:4.7.2` Docker image, locally through `tools/godot.sh` and in CI as the job container. A tiny headless test runner (no add-ons) checks the drag logic and the level flow.

**Tech Stack:** Godot 4.7.2-stable (GDScript, Compatibility renderer), Docker, Python 3 + Pillow (placeholder assets), GitHub Actions, GitHub Pages, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-10-29-cruise-adventure-v0.1-design.md` (approved; takes precedence) and `docs/cruise-adventure-v0.1-spec.md`. Read both.

## Global Constraints

- Godot version **4.7.2-stable** and CI image **`barichello/godot-ci:4.7.2`**. Never `latest`.
- GDScript only. Renderer `gl_compatibility` for desktop and mobile.
- Base resolution 1920 x 1080, `stretch/mode="canvas_items"`, `stretch/aspect="expand"`, landscape locked.
- `input_devices/pointing/emulate_mouse_from_touch=true`. One input path, mouse events only.
- Web export: `variant/thread_support=false`.
- Every visual and sound is a file in `assets/`. Nothing is drawn in code (no `_draw`, no `ColorRect` art).
- Version lives only in `application/config/version="0.1.0"` in `project.godot`. Android `version/name` stays empty so Godot uses it. Android `version/code=1`.
- Android package `com.polarispixels.cruiseadventure`, app name "Cruise Adventure", both `arm64-v8a` and `armeabi-v7a`.
- Never commit a keystore, a password, or `build/`. The keystore lives in `~/keystores/cruise-adventure/` (WSL).
- No reading needed to play. No failure sounds or states. Unlimited retries.
- Repo `polarispixels/cruise-adventure`, **public**. Pages URL `https://polarispixels.github.io/cruise-adventure/`.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Grabbing again after success:** once the shirt is placed it must not be draggable until Replay. Test `test_cannot_drag_after_placed` (Task 3).
2. **Replay pressed mid-celebration:** reset must kill running tweens, so the shirt ends on the bed, the check is hidden and nothing pops back. Test `test_reset_during_celebration` (Task 4).
3. **Drop on the suitcase's edge:** a 4-year-old's release lands near the edge; anywhere within `DROP_MARGIN` of the suitcase counts. Test `test_drop_zone_margin` (Task 3).
4. **Taps that miss the shirt:** a tap on empty floor must not grab the shirt or teleport it. Test `test_begin_drag_outside_does_nothing` (Task 3).
5. **Non-16:9 screens (16:10 Fire, 4:3, 20:9):** expand aspect reveals extra world space, and the background must cover it so there are no bars or bare edges. Test `test_background_covers_wide_and_tall` (Task 4).

## File Map

| File | Responsibility |
| --- | --- |
| `project.godot` | engine, display, input, version settings |
| `export_presets.cfg` | Web + Android presets, no secrets |
| `scripts/draggable.gd` | generic pick up / follow / drop / snap-or-return (`class_name Draggable`) |
| `scenes/shirt.tscn` | a `Draggable` with the shirt sprite |
| `scripts/main.gd` | wires item to level: celebration, reset, version stamp |
| `scenes/main.tscn` | the bedroom level |
| `tests/run_tests.gd` | headless test runner (extends `SceneTree`), exits 1 on failure |
| `tests/test_draggable.gd`, `tests/test_main.gd` | test cases |
| `tools/godot.sh` | runs any Godot command in the pinned Docker image |
| `tools/make_placeholders.py`, `tools/make_chime.py` | generate `assets/` (committed outputs) |
| `.github/workflows/build.yml` | test, web → Pages, Android → artifact / Release |
| `README.md`, `CHANGELOG.md`, `.gitignore` | docs and hygiene |

---

### Task 1: Repo, project skeleton, Docker wrapper, test runner

**Files:**
- Create: `.gitignore`, `project.godot`, `tools/godot.sh`, `tools/.gdignore`, `docs/.gdignore`, `tests/run_tests.gd`, `tests/test_smoke.gd`, `README.md` (stub: one paragraph + "see docs/"), `CHANGELOG.md` (header only)

**Interfaces:**
- Produces: `tools/godot.sh <godot args...>` — runs `godot <args>` in `barichello/godot-ci:4.7.2` with the repo mounted at `/project` as the working dir. Test convention: each `tests/test_*.gd` extends `RefCounted`, every method starting `test_` is run with one argument `t` (the runner). The runner exposes `t.check(cond: bool, msg: String)`, `t.eq(a, b, msg: String)`, and `t.tree` (the `SceneTree`), and test methods may `await`. Run all tests with `tools/godot.sh --headless --script res://tests/run_tests.gd`.

- [ ] **Step 1: Check Docker can see WSL files.** Run `docker run --rm -v "$PWD:/project" -w /project barichello/godot-ci:4.7.2 sh -c 'ls /project && godot --version'`. Expected: the repo files are listed, then `4.7.2.stable.official...`. If `/project` is empty, Docker Desktop's WSL integration is off. Use `-v "$(wslpath -w "$PWD"):/project"` in `godot.sh` instead, and note this in the README.
- [ ] **Step 2: Write `tools/godot.sh`.** Use the mount form from Step 1 and pass `"$@"` through. Run as the host uid (`--user "$(id -u):$(id -g)"`) so `.godot/` isn't owned by root. If templates then can't be found under the new `HOME`, set `-e HOME=/root` and drop `--user` instead.
- [ ] **Step 3: Write `.gitignore`.** Include `.godot/`, `build/`, `*.keystore`, `*.jks`, `*.apk`, `*.aab`, `export_credentials.cfg`, and `__pycache__/`.
- [ ] **Step 4: Write `project.godot`** with `config_version=5` and these settings:
  - `application/config/name="Cruise Adventure"`, `config/version="0.1.0"`, `run/main_scene="res://scenes/main.tscn"`, `config/features=PackedStringArray("4.7", "GL Compatibility")`, `config/icon="res://assets/art/icon.png"`
  - display: `window/size/viewport_width=1920`, `viewport_height=1080`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, `window/handheld/orientation=0`
  - `input_devices/pointing/emulate_mouse_from_touch=true`
  - rendering: `renderer/rendering_method="gl_compatibility"`, `renderer/rendering_method.mobile="gl_compatibility"`, `textures/vram_compression/import_etc2_astc=true` (Android export refuses without it)

  The main scene and icon don't exist yet. That's fine until Task 4.
- [ ] **Step 5: Write `tests/run_tests.gd` and `tests/test_smoke.gd`.** The runner discovers `res://tests/test_*.gd` and runs every `test_*` method in sorted order, `await`ing each. It prints `PASS name` / `FAIL name: msg`, ends with `N passed, M failed`, and calls `quit(1)` if anything failed, otherwise `quit(0)`. The smoke test asserts `t.eq(ProjectSettings.get_setting("application/config/version"), "0.1.0", "version")`.
- [ ] **Step 6: Import and run the tests.** Run `tools/godot.sh --headless --import` and then `tools/godot.sh --headless --script res://tests/run_tests.gd`. Expected: `PASS test_version_setting` and `1 passed, 0 failed`, exit 0. Import warnings about the missing main scene and icon are OK.
- [ ] **Step 7: Check the runner fails correctly.** Temporarily change the expected version to `"9.9.9"` and rerun. Expected: exit code 1 and a `FAIL` line. Revert.
- [ ] **Step 8: Init the repo, commit, create the GitHub repo and push.**
```bash
git init -b main && git add -A && git commit -m "chore: project skeleton, docker godot wrapper, test runner"
gh repo create polarispixels/cruise-adventure --public --source=. --push
```

### Task 2: Placeholder art and chime

**Files:**
- Create: `tools/make_placeholders.py`, `tools/make_chime.py`, `assets/art/*.png`, `assets/audio/chime.ogg`

**Interfaces:**
- Produces the files below (exact names and pixel sizes; later tasks lay out the scene with these sizes):

| File | Size | Look |
| --- | --- | --- |
| `bedroom.png` | 2880 x 1800 | pale wall on the top 60%, wood-tone floor below |
| `bed.png` | 700 x 400 | blue blanket rectangle, white pillow |
| `suitcase.png` | 760 x 500 | open red/orange case, darker interior |
| `shirt.png` | 260 x 220 | yellow T-shirt silhouette (polygon) |
| `slot.png` | 280 x 240 | the shirt silhouette as a thick glowing white outline on transparent |
| `check.png` | 360 x 360 | big green checkmark on transparent |
| `replay.png` | 240 x 240 | white circular arrow on a green circle |
| `star.png` | 96 x 96 | yellow 5-point star |
| `icon.png` | 512 x 512 | suitcase-on-blue app icon |

- `chime.ogg`: about 0.6 s, a bright two-note rising chime (e.g. E6 then B6, sine waves plus a soft harmonic, exponential decay), mono 44.1 kHz.

- [ ] **Step 1: Write `tools/make_placeholders.py`.** Use Pillow, flat colours and thick shapes with rounded corners. It writes every PNG above and is idempotent.
- [ ] **Step 2: Write `tools/make_chime.py`.** Synthesize with `numpy` (or pure `math` + `wave`) to a WAV. Then encode to `.ogg` by running `ffmpeg -i chime.wav -c:a libvorbis assets/audio/chime.ogg` in a throwaway container (`docker run --rm -v ... jrottenberg/ffmpeg:6.1-alpine ...`), or with `soundfile` if pip-installable. Delete the WAV.
- [ ] **Step 3: Run both scripts.** Then run `python3 -c "from PIL import Image; import glob; [print(f, Image.open(f).size) for f in sorted(glob.glob('assets/art/*.png'))]"`. Expected: all 9 files at the sizes in the table. Also check `file assets/audio/chime.ogg`. Expected: `Ogg data, Vorbis audio`.
- [ ] **Step 4: Run `tools/godot.sh --headless --import`.** Expected: no import errors for `assets/`, and `.import` sidecar files appear next to each asset.
- [ ] **Step 5: Commit** the scripts, the assets and their `.import` files: `feat: placeholder art and chime`.

### Task 3: Generic Draggable + shirt scene

**Files:**
- Create: `scripts/draggable.gd`, `scenes/shirt.tscn`, `tests/test_draggable.gd`

**Interfaces:**
- Produces `class_name Draggable extends Node2D`:
  - `signal placed(item: Draggable)`
  - `@export var drop_zone: Rect2`: global-space rect, set by the level
  - `@export var snap_point: Vector2`: global position the item snaps to
  - `const DROP_MARGIN := 80.0`, `const GRAB_PADDING := 40.0`, `const LIFT_SCALE := 1.15`, `const SNAP_TIME := 0.25`, `const RETURN_TIME := 0.4`
  - `var home_position: Vector2`, captured in `_ready()`
  - `var is_placed: bool`, `var is_dragging: bool`
  - `static func in_drop_zone(point: Vector2, zone: Rect2, margin: float) -> bool`: `zone.grow(margin).has_point(point)`
  - `func begin_drag(global_point: Vector2) -> bool`: starts a drag only if not placed, not already dragging, and the point is inside the sprite's global rect grown by `GRAB_PADDING`. Lifts the item (scale `LIFT_SCALE`, shows the `Shadow` child, raises `z_index`). Returns whether it started.
  - `func drag_to(global_point: Vector2) -> void`: follows the pointer keeping the grab offset, and only while dragging.
  - `func end_drag(global_point: Vector2) -> bool`: if the item is in the drop zone (checked with the *item's* position, not the pointer), tweens to `snap_point` over `SNAP_TIME`, sets `is_placed`, emits `placed` and returns true. Otherwise tweens back to `home_position` over `RETURN_TIME` and returns false. Either way it un-lifts the item.
  - `func reset() -> void`: kills the active tween, then puts the item home immediately with scale 1, not placed and not dragging.
  - `_unhandled_input` maps `InputEventMouseButton` (left, pressed/released) and `InputEventMouseMotion` to the three methods using `get_global_mouse_position()`. Calls `get_viewport().set_input_as_handled()` when it consumes an event.
- `scenes/shirt.tscn`: root `Shirt` (Draggable) → `Shadow` (Sprite2D `shirt.png`, `modulate = Color(0,0,0,0.3)`, offset (12,16), hidden) → `Sprite` (Sprite2D `shirt.png`, centered). Using the shirt texture for the shadow keeps the "no drawing in code" rule.

- [ ] **Step 1: Write the failing tests in `tests/test_draggable.gd`.** Each test instantiates `shirt.tscn`, sets `position = Vector2(480, 600)`, `drop_zone = Rect2(1020, 430, 760, 500)` and `snap_point = Vector2(1400, 660)`, adds it to `t.tree.root`, awaits one frame, and `queue_free`s it at the end.
  - `test_drop_zone_margin`: `in_drop_zone(Vector2(1000, 600), zone, 80)` is true, `(930, 600)` is false, `(1400, 680)` is true
  - `test_begin_drag_outside_does_nothing`: `begin_drag(Vector2(100, 100))` is false, `is_dragging` is false, and position is unchanged
  - `test_drag_follows_pointer`: `begin_drag(Vector2(490, 610))` is true, then `drag_to(Vector2(800, 400))`, then position == `(790, 390)` and scale == `Vector2.ONE * LIFT_SCALE`
  - `test_drop_in_suitcase_snaps`: drag to `(1400, 650)`, `end_drag` returns true, `placed` was emitted once, and after awaiting `SNAP_TIME + 0.1` s position ≈ `snap_point` (within 1 px) and scale is 1
  - `test_missed_drop_returns_home_quickly`: drag to `(900, 200)`, `end_drag` returns false, and after awaiting 0.5 s position ≈ home (within 1 px)
  - `test_cannot_drag_after_placed`: after a successful drop, `begin_drag(snap_point)` is false
  - `test_reset_restores`: after a successful drop, `reset()` puts position at home with `is_placed` false, and `begin_drag` works again
- [ ] **Step 2: Run the tests and confirm they fail.** Expected: the `shirt.tscn` / `Draggable` loads fail.
- [ ] **Step 3: Implement `scripts/draggable.gd` and `scenes/shirt.tscn`** to the interface above. Hand-write the `.tscn` in Godot 4 text format (`[gd_scene load_steps=... format=3]`, `ext_resource` with `uid` omitted is fine).
- [ ] **Step 4: Import and run the tests.** Run `tools/godot.sh --headless --import` and then the runner. Expected: all draggable tests and the smoke test PASS, exit 0.
- [ ] **Step 5: Commit:** `feat: generic draggable item and shirt scene`.

### Task 4: Bedroom level, celebration, replay, version stamp

**Files:**
- Create: `scripts/main.gd`, `scenes/main.tscn`, `tests/test_main.gd`

**Interfaces:**
- Consumes: `Draggable` (Task 3), assets (Task 2).
- `scenes/main.tscn` node tree (root `Main`, Node2D, script `main.gd`). Positions are in the 1920 x 1080 world:
  - `Camera2D`, position (960, 540), enabled. With expand aspect this keeps the 1920 x 1080 design centred.
  - `Background` Sprite2D `bedroom.png`, centered at (960, 540). At 2880 x 1800 it covers viewports up to 2880 x 1800 around the centre.
  - `Bed` Sprite2D `bed.png` at (480, 680)
  - `Suitcase` Sprite2D `suitcase.png` at (1400, 680)
  - `Slot` Sprite2D `slot.png` at (1400, 660)
  - `Shirt` (instance `shirt.tscn`) at (480, 600)
  - `Stars` Node2D (empty container)
  - `Check` Sprite2D `check.png` at (1400, 620), hidden
  - `ReplayButton` TextureButton `replay.png` at top-left (1280, 820) so it's centred at about (1400, 940); hidden
  - `Chime` AudioStreamPlayer with `chime.ogg`
  - `UI` CanvasLayer → `VersionLabel` Label anchored bottom-left, offset 16 px, font size 24, semi-transparent white
- `main.gd` produces:
  - `const STAR_COUNT := 8`
  - `static func version_text() -> String`: `"v" + str(ProjectSettings.get_setting("application/config/version"))`
  - `func _ready()`: sets `VersionLabel.text`, sets `Shirt.drop_zone` to the Suitcase sprite's global rect and `Shirt.snap_point` to the Slot's global position, connects `Shirt.placed` → `_on_item_placed` and `ReplayButton.pressed` → `reset_level`
  - `func _on_item_placed(item: Draggable) -> void`: hides Slot, plays Chime, spawns `STAR_COUNT` `star.png` Sprite2Ds under `Stars` at the slot that tween outward ~250 px and fade over 0.7 s, shows Check with a scale pop (0 → 1.2 → 1, ~0.3 s), then shows ReplayButton after ~0.6 s. Keep every tween in a list so they can be killed.
  - `func reset_level() -> void`: kills the celebration tweens, frees the star children, hides Check and ReplayButton, shows Slot and calls `Shirt.reset()`

- [ ] **Step 1: Write the failing tests in `tests/test_main.gd`.** Each test instantiates `main.tscn` into `t.tree.root`, awaits a frame and frees it at the end.
  - `test_version_stamp`: `$UI/VersionLabel.text == "v0.1.0"`
  - `test_success_sequence`: call `shirt.begin_drag(shirt.global_position)`, `drag_to(Vector2(1400, 660))` and `end_drag(...)`, then await 1.0 s. Expect Check visible, ReplayButton visible, Slot hidden and `Stars.get_child_count() == STAR_COUNT` (or 0 if they free on finish, so pick one and assert it).
  - `test_reset_during_celebration`: drop successfully, await 0.1 s, call `reset_level()`, await 1.0 s. Expect shirt at home, Check and ReplayButton hidden, Slot visible, no star children, `shirt.is_placed == false`.
  - `test_replay_repeatable`: run success then reset 3 times in a row, and every success fires `placed`
  - `test_background_covers_wide_and_tall`: Background texture size ≥ (2400, 1440). That covers 20:9 (2400 x 1080) and 4:3 (1920 x 1440) under expand.
  - `test_drop_zone_matches_suitcase`: `shirt.drop_zone` equals the Suitcase sprite's global rect `Rect2(1020, 430, 760, 500)`
- [ ] **Step 2: Run the tests and confirm they fail.**
- [ ] **Step 3: Implement `scenes/main.tscn` and `scripts/main.gd`** to the interface.
- [ ] **Step 4: Import and run all tests.** Expected: all PASS, exit 0, and no `ERROR:` lines in the output.
- [ ] **Step 5: Commit:** `feat: bedroom level with celebration, replay and version stamp`.

### Task 5: Export presets and local web build

**Files:**
- Create: `export_presets.cfg`
- Modify: `README.md` (local build instructions)

**Interfaces:**
- Produces presets named exactly `"Web"` (index 0, `export_path="build/web/index.html"`) and `"Android"` (index 1, `export_path="build/android/cruise-adventure.apk"`). CI calls them by name.
- Web options: `variant/thread_support=false`, `html/canvas_resize_policy=2`, `progressive_web_app/enabled=false`, `vram_texture_compression/for_mobile=true`.
- Android options: `gradle_build/use_gradle_build=false`, `architectures/armeabi-v7a=true`, `architectures/arm64-v8a=true`, `version/code=1`, `version/name=""`, `package/unique_name="com.polarispixels.cruiseadventure"`, `package/name="Cruise Adventure"`, `screen/immersive_mode=true`, `launcher_icons/main_192x192="res://assets/art/icon.png"`, and empty `keystore/*` fields (CI supplies them through env vars).

- [ ] **Step 1: Write `export_presets.cfg`.** Godot 4 format: `[preset.0]` + `[preset.0.options]`, and the same for 1.
- [ ] **Step 2: Export the web build.** Run `mkdir -p build/web && tools/godot.sh --headless --export-release "Web" build/web/index.html`. Expected: exit 0, with `build/web/index.html`, `index.js`, `index.wasm` and `index.pck` present.
- [ ] **Step 3: Check the Android preset is valid** (debug-signed, which proves templates and SDK work). Run `mkdir -p build/android && tools/godot.sh --headless --export-debug "Android" build/android/debug.apk`. Expected: exit 0 and the APK exists. If it fails over the debug keystore, the image's editor settings may not be under the container `HOME`. Fix `godot.sh` as in Task 1 Step 2 instead of editing the preset.
- [ ] **Step 4: Have Ryan smoke-test it.** Run `python3 -m http.server 8060 -d build/web` in the background, ask Ryan to open `http://localhost:8060` in a desktop browser, drag the shirt with the mouse and confirm the chime, stars, check, replay and `v0.1.0` stamp. Stop the server afterwards.
- [ ] **Step 5: Commit:** `build: web and android export presets`.

### Task 6: Release keystore and repo secrets

**Files:** none in the repo. Writes `~/keystores/cruise-adventure/release.keystore` and `password.txt` (chmod 600).

- [ ] **Step 1: Generate a password and the keystore.** Generate the password with `openssl rand -base64 24 | tr -d '/+='` and save it to `password.txt`. Then run `keytool -genkeypair -v -keystore /out/release.keystore -alias cruiseadventure -keyalg RSA -keysize 2048 -validity 10000 -storepass "$PW" -keypass "$PW" -dname "CN=Polaris Pixels, O=Polaris Pixels, C=US"` inside `barichello/godot-ci:4.7.2`, with `~/keystores/cruise-adventure` mounted at `/out`.
- [ ] **Step 2: Verify the keystore.** Run `keytool -list -keystore /out/release.keystore -storepass "$PW"` in the same image. Expected: one `PrivateKeyEntry` with alias `cruiseadventure`.
- [ ] **Step 3: Set the repo secrets.** Set `ANDROID_KEYSTORE_BASE64` (`base64 -w0 release.keystore | gh secret set ANDROID_KEYSTORE_BASE64 -R polarispixels/cruise-adventure`), `ANDROID_KEYSTORE_ALIAS=cruiseadventure` and `ANDROID_KEYSTORE_PASSWORD`. Verify with `gh secret list -R polarispixels/cruise-adventure`, which should show all 3.
- [ ] **Step 4: Confirm nothing leaked into the repo.** `git status` should show nothing from `~/keystores`, and `git grep -n "$PW"` should find nothing. **Tell Ryan to back up `~/keystores/cruise-adventure/` now** (it's reachable from Windows at `\\wsl$\Ubuntu\home\rgris\keystores\cruise-adventure`, or wherever the distro name puts it).

### Task 7: CI workflow, Pages

**Files:**
- Create: `.github/workflows/build.yml`

**Interfaces:**
- Triggers: `push` to `main` and tags `v*`, plus `workflow_dispatch`.
- Env: `GODOT_VERSION: 4.7.2`.
- Jobs:
  1. `test`: container `barichello/godot-ci:4.7.2`. Runs a setup step that moves the templates and editor settings from `/root` into `$HOME`, the usual godot-ci step for GitHub containers: `mkdir -p ~/.local/share/godot/export_templates ~/.config && mv /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable ~/.local/share/godot/export_templates/ && mv /root/.config/godot ~/.config/godot` (skip if `$HOME` is `/root`). Then `godot --headless --import` and the test runner.
  2. `web` (needs test): same container and setup, export `"Web"` to `build/web/index.html`, then `actions/upload-pages-artifact@v3` with `path: build/web`.
  3. `deploy-pages` (needs web, `if: github.ref == 'refs/heads/main'`, because the `github-pages` environment only allows the default branch, and a tag's commit is already on main): `permissions: pages: write, id-token: write`, `environment: github-pages`, `actions/deploy-pages@v4`.
  4. `android` (needs test): same container and setup. Decode `secrets.ANDROID_KEYSTORE_BASE64` to `$RUNNER_TEMP/release.keystore` and export `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` (alias secret) and `_PASSWORD`. On tags, first **fail if** `${GITHUB_REF_NAME#v}` ≠ the version in `project.godot` (grep `config/version`). Then export release `"Android"` to `build/android/cruise-adventure.apk`, rename it to `cruise-adventure-${GITHUB_REF_NAME}.apk` on tags or `cruise-adventure-${GITHUB_SHA::7}.apk` otherwise, and `actions/upload-artifact@v4`.
  5. `release` (needs android, `if: startsWith(github.ref, 'refs/tags/v')`): `runs-on: ubuntu-latest`, `permissions: contents: write`, download the artifact, then `gh release create "$GITHUB_REF_NAME" cruise-adventure-$GITHUB_REF_NAME.apk --title "$GITHUB_REF_NAME" --notes-file <(the CHANGELOG section for this version)` with `GH_TOKEN: ${{ github.token }}`.
- Top-level `concurrency: group: pages, cancel-in-progress: false` on the deploy job only.

- [ ] **Step 1: Enable Pages with the Actions source.** Run `gh api -X POST repos/polarispixels/cruise-adventure/pages -f build_type=workflow`. Expected: `"build_type": "workflow"`. A 409 means it already exists; then use `-X PUT`.
- [ ] **Step 2: Write `build.yml`** to the interface above.
- [ ] **Step 3: Push and watch.** Run `git add .github && git commit -m "ci: build web and android, deploy pages"` and `git push`, then `gh run watch --exit-status`. Expected: test, web, deploy-pages and android all succeed, and release is skipped.
- [ ] **Step 4: Check Pages and the artifact.** Run `curl -sI https://polarispixels.github.io/cruise-adventure/ | head -1`. Expected: `HTTP/2 200`. `gh run download` of the android artifact should produce an `.apk` over 20 MB.
- [ ] **Step 5: Check the tag-mismatch guard.** Push a throwaway tag `v9.9.9` and confirm the android job fails on the version check without creating a Release. Then delete it (`git push --delete origin v9.9.9 && git tag -d v9.9.9`) and cancel or ignore that run.

### Task 8: Docs, release v0.1.0, tablet install

**Files:**
- Modify: `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Write the README** for Ryan, a non-Godot user. Cover: what this is; play links (Pages URL, Releases page); how to install on the Fire tablet (Silk → Releases page → tap the APK → allow "Apps from unknown sources" under Settings → Security → open "Cruise Adventure"); how to make a release (bump `config/version` in `project.godot` **and** `version/code` in `export_presets.cfg` by 1, add a CHANGELOG entry, tag `vX.Y.Z`, push the tag); local commands (`tools/godot.sh --headless --import`, run tests, web export, local serve); placeholder regeneration; and **the keystore warning with its location**.
- [ ] **Step 2: Write the CHANGELOG** entry `## [0.1.0] - 2026-10-29` with what v0.1 contains.
- [ ] **Step 3: Tag and push.** Commit `docs: readme and changelog for v0.1.0`, push, `git tag v0.1.0 && git push origin v0.1.0`, then `gh run watch --exit-status`. Expected: all jobs green including release. Run `gh release view v0.1.0 --json assets --jq '.assets[].name'`. Expected: `cruise-adventure-v0.1.0.apk`.
- [ ] **Step 4: Ryan's acceptance on the tablet and desktop.** Ask Ryan to install from the Releases page on the Fire tablet and to open the Pages URL on desktop. He then checks the spec's acceptance list: finger drag, generous drop, snap+chime+stars+check, miss returns, endless replay, landscape fill with no bars, and the stamp reading `v0.1.0`. Fix anything he reports as a new task before calling v0.1 done.
