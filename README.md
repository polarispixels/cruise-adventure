# Jack-Jack and Becca's Cruise Adventure

A Godot game for Jack-Jack (6) and Becca (4) about their family cruise, played on a Fire tablet and in the browser. Part 1, packing, is done: the kid packs their whole picture card, row by row. Part 2 is the journey to the ship, one stop at a time: loading the car (the trunk puzzle) is in playtest, and the airport is next. The overall spec is `docs/cruise-adventure-game-spec.md`; chapter specs live in the Kids Packing Video `Specs\` folder; how work ships is in `docs/deployment.md`.

- **Play in a browser:** https://polarispixels.github.io/cruise-adventure/
- **Download the Android APK:** https://github.com/polarispixels/cruise-adventure/releases
- **Project page (story arc, storyboard, checklists, voices):** https://polarispixels.github.io/cruise-adventure/docs/

The project page is built on every deploy by `tools/make_docs_site.py` from `docs/site/story.json`; its checklists tick themselves from the repo (files, recorded voice lines, playable rows). Edit `story.json` to change the story or add checks. After new keyframes or clips arrive, run `python3 tools/make_docs_images.py` to refresh the pictures in `docs/site/img/`, and commit them. Preview: `python3 tools/make_docs_site.py build/web/docs`.

**How work ships** (local preview, tablet playtests, the live site, official releases): see [docs/deployment.md](docs/deployment.md).

## Install on the Fire tablet

1. On the tablet, open **Silk** (or Chrome on a regular Android tablet) and go to the Releases page above.
2. Under the newest release, tap `cruise-adventure-vX.Y.Z.apk` to download it, then open the download.
3. The first time, the tablet asks to allow installs from this browser. Allow it. On a Fire tablet the setting is under **Settings → Security & Privacy → Apps from Unknown Sources**.
4. Tap **Install**. The game appears on the home screen as **Cruise Adventure**.

New versions install over the old one, because every build is signed with the same key (see below).

## Make a release

1. Make sure all art is approved: `python3 tools/check_art_approved.py` (see [Art and sound](#art-and-sound)).
2. Check that `config/version` in `project.godot` is the version you're releasing. It's bumped at the start of each version branch (see [docs/deployment.md](docs/deployment.md#version-numbers)), together with `version/code` in `export_presets.cfg`. Android refuses an update with a lower code.
3. Leave `config/build` empty. CI stamps it on non-release builds, and a tag build shows the bare version.
4. Add a `## [X.Y.Z] - YYYY-MM-DD` entry to `CHANGELOG.md`. Its text becomes the release notes.
5. Commit and push to `main`, then tag and push the tag:
   ```bash
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```
6. The `build` workflow publishes a GitHub Release with `cruise-adventure-vX.Y.Z.apk` attached. If the tag doesn't match `config/version`, the build fails without releasing anything.

Every push to `main` also rebuilds the web version on GitHub Pages and keeps a signed APK as a downloadable workflow artifact.

## The signing key — back it up

The release keystore and its password live **outside the repo**, at `~/keystores/cruise-adventure/` in WSL. From Windows that's `\\wsl.localhost\Ubuntu\home\rgris\keystores\cruise-adventure`. GitHub holds a copy only as the encrypted secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS` and `ANDROID_KEYSTORE_PASSWORD`, which can't be read back.

**If the keystore is lost, the tablet can never update the installed game without uninstalling it first.** Keep a copy somewhere safe, such as a password manager. Never commit it.

## Local commands

All Godot commands run inside the pinned CI image (`barichello/godot-ci:4.7.2`) through `tools/godot.sh`, so you never need Godot installed. Docker Desktop must be running.

```bash
tools/godot.sh --headless --import                               # import assets (first run, or after art changes)
tools/godot.sh --headless --script res://tests/run_tests.gd     # run the tests
tools/export_web.sh                                              # web build, labeled "local MMDD-HHMM"
python3 -m http.server 8060 -d build/web                         # play at http://localhost:8060
```

To open the scenes visually, install exactly **Godot 4.7.2** (standard, not .NET) and open `project.godot`. Editor and CI must use the same version.

## Art and sound

Every picture, sound and video is a file in `assets/`. Nothing is drawn in code. The art is made in the Kids Packing Video project and pulled in here; this repo never writes to that project.

`data/art_manifest.json` lists every art file: where it comes from, how it's made, and whether Ryan has approved it.

```bash
python3 tools/import_art.py          # copy art in, recolor the clothing variants, make UI placeholders, voice and video
tools/godot.sh --headless --import   # let Godot import the new files
python3 tools/layout_preview.py      # build/layout-<kid>.png: room layout over the art, with the tablet's 16:10 crop
```

`ART_ROOT` points the import at the art project (default: `C:\Users\rgris\Documents\ChatGPT\Kids Packing Video` via `/mnt/c`). When new art arrives with the same file names, re-run the import; no code changes.

**Voices.** `python3 tools/import_voice.py` builds every spoken line in `data/voice_lines.json` for both helpers. It uses the first recording it finds: the kid's own in the art project's `Voice/<Jack-Jack|Becca>/`, then `recordings/<jack|becca>/`, then `recordings/shared/` (one grown-up voice for both). Files are named by line ID, any of m4a/wav/mp3/ogg. Silence at both ends is trimmed and volume evened out. Lines with no recording get a computer voice.

**Approving art.** Test builds may use provisional art, but a release may not. When Ryan approves a file, set its `"approved": true` in the manifest. `python3 tools/check_art_approved.py` lists anything still waiting, and the release job runs it and refuses to publish until the list is empty.

Room positions (kids, suitcase, the pile on the rug, the card) live in `data/room_layout.json` in background pixels. Check changes with the layout preview.

## Layout

| Path | What it is |
| --- | --- |
| `project.godot` | engine settings and the version |
| `export_presets.cfg` | Web and Android export settings (no secrets) |
| `scripts/game.gd` | autoload: who is playing, moving between scenes |
| `data/jack.tres`, `data/becca.tres` | each kid's settings: art, number of choices, hint delay, intro video |
| `scenes/title.tscn` | pick a kid; version stamp |
| `scenes/intro.tscn` | the kid's intro video (tap to skip) |
| `scenes/room.tscn` | the packing flow: suitcase, card, drawer, roll, pack, close, zip |
| `scenes/drawer_view.tscn` | the Find matching game |
| `scenes/character.tscn`, `card.tscn`, `zipper.tscn`, `item.tscn` | reusable pieces (`item.tscn` is any draggable item) |
| `data/art_manifest.json`, `data/room_layout.json` | where the art comes from; where things sit in the room |
| `tests/` | headless tests (`run_tests.gd` runs every `test_*.gd`) |
| `.github/workflows/build.yml` | tests, web → Pages, Android → artifact / Release |
