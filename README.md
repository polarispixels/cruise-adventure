# Jack-Jack and Becca's Cruise Adventure

A one-screen Godot game for Jack (6) and Becca (4): drag the shirt into the suitcase. Version 0.1 exists to prove the pipeline from GitHub to the cloud build to the web and the Fire tablet. The spec and design are in `docs/`.

- **Play in a browser:** https://polarispixels.github.io/cruise-adventure/
- **Download the Android APK:** https://github.com/polarispixels/cruise-adventure/releases

## Install on the Fire tablet

1. On the tablet, open **Silk** (or Chrome on a regular Android tablet) and go to the Releases page above.
2. Under the newest release, tap `cruise-adventure-vX.Y.Z.apk` to download it, then open the download.
3. The first time, the tablet asks to allow installs from this browser. Allow it. On a Fire tablet the setting is under **Settings → Security & Privacy → Apps from Unknown Sources**.
4. Tap **Install**. The game appears on the home screen as **Cruise Adventure**.

New versions install over the old one, because every build is signed with the same key (see below).

## Make a release

1. In `project.godot`, bump `config/version` (for example `"0.1.0"` → `"0.2.0"`). This is the only place the human version lives.
2. In `export_presets.cfg`, raise `version/code` by 1. Android refuses an update with the same or a lower code.
3. Add a `## [X.Y.Z] - YYYY-MM-DD` entry to `CHANGELOG.md`. Its text becomes the release notes.
4. Commit and push to `main`, then tag and push the tag:
   ```bash
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```
5. The `build` workflow publishes a GitHub Release with `cruise-adventure-vX.Y.Z.apk` attached. If the tag doesn't match `config/version`, the build fails without releasing anything.

Every push to `main` also rebuilds the web version on GitHub Pages and keeps a signed APK as a downloadable workflow artifact.

## The signing key — back it up

The release keystore and its password live **outside the repo**, at `~/keystores/cruise-adventure/` in WSL. From Windows that's `\\wsl.localhost\Ubuntu\home\rgris\keystores\cruise-adventure`. GitHub holds a copy only as the encrypted secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS` and `ANDROID_KEYSTORE_PASSWORD`, which can't be read back.

**If the keystore is lost, the tablet can never update the installed game without uninstalling it first.** Keep a copy somewhere safe, such as a password manager. Never commit it.

## Local commands

All Godot commands run inside the pinned CI image (`barichello/godot-ci:4.7.2`) through `tools/godot.sh`, so you never need Godot installed. Docker Desktop must be running.

```bash
tools/godot.sh --headless --import                               # import assets (first run, or after art changes)
tools/godot.sh --headless --script res://tests/run_tests.gd     # run the tests
mkdir -p build/web && tools/godot.sh --headless --export-release "Web" build/web/index.html
python3 -m http.server 8060 -d build/web                         # play at http://localhost:8060
```

To open the scenes visually, install exactly **Godot 4.7.2** (standard, not .NET) and open `project.godot`. Editor and CI must use the same version.

## Art and sound

Every picture and sound is a file in `assets/`. Nothing is drawn in code. The v0.1 placeholders come from `tools/make_placeholders.py` and `tools/make_chime.py`, using the palette of the Kids Packing Video. To use the kids' illustrations instead, replace the PNGs with files of the same names; the game code doesn't change.

## Layout

| Path | What it is |
| --- | --- |
| `project.godot` | engine settings and the version |
| `export_presets.cfg` | Web and Android export settings (no secrets) |
| `scenes/main.tscn`, `scripts/main.gd` | the bedroom level: celebration, replay, version stamp |
| `scenes/shirt.tscn`, `scripts/draggable.gd` | a generic draggable item (any item, any target) |
| `tests/` | headless tests (`run_tests.gd` runs every `test_*.gd`) |
| `.github/workflows/build.yml` | tests, web → Pages, Android → artifact / Release |
