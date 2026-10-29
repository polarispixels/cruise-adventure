# Cruise Adventure v0.1 Spec

Oct 29, 2026 · @Ryan Grissinger

## Overview

Version 0.1 of Jack-Jack and Becca's Cruise Adventure is a one-screen Godot game: drag one shirt into an open suitcase and it snaps in with a celebration. The real goal is proving the pipeline end to end, from a Godot project in GitHub, to an automatic build on every push, to a web version on GitHub Pages and an APK installed on the Android tablet.

v0.1 is done when the kids can play it on the tablet and the same build runs in a desktop browser.

## Gameplay

The player drags the shirt into the suitcase. That is the entire game. Nothing on screen requires reading.

1. **Scene.** A simple bedroom: wall, floor, a bed on the left with a folded shirt on it, an open suitcase on the right with one glowing outline slot showing where the shirt goes.
2. **Pick up.** Touching the shirt lifts it slightly (scale up, soft shadow) and it follows the finger.
3. **Drop in the slot.** Releasing over the suitcase snaps the shirt into the slot with a short ease, plays a chime, and pops a burst of stars. A big green checkmark stamps over the suitcase.
4. **Drop anywhere else.** The shirt glides back to the bed. No sound of failure, no penalty.
5. **Replay.** After the checkmark, a large circular-arrow button appears. Tapping it resets the scene.
6. **Version stamp.** "v0.1.0" in small text in the bottom-left corner, read from the project's version setting, so you can confirm which build is installed.

### Acceptance criteria

- [ ] Dragging works with a finger on the tablet and with a mouse in the browser, through one code path
- [ ] A drop anywhere over the suitcase counts (generous drop zone, at least the full suitcase interior)
- [ ] Snap, chime, stars, and checkmark all fire on success
- [ ] A missed drop returns the shirt to the bed within about half a second
- [ ] Replay resets everything and can be repeated indefinitely
- [ ] Runs locked to landscape and fills the tablet screen without black bars on common 16:10 and 16:9 tablets
- [ ] Version stamp matches the release tag

## Tech stack and hard rules

| Decision | Choice | Why |
| --- | --- | --- |
| Engine | Godot 4, latest stable, one exact version pinned in both the editor and CI | Editor and build must match or exports break |
| Language | GDScript only | Godot's C# builds cannot export to the web |
| Renderer | Compatibility | Required for web export and the safest choice for budget Android and Fire tablets |
| Base resolution | 1920 x 1080, stretch mode canvas\_items, aspect expand | Crisp on tablets, scales cleanly to any landscape screen |
| Orientation | Landscape, locked | Two-handed tablet play, matches future levels |
| Input | Touch with "emulate mouse from touch" on | One input code path for finger and mouse |
| Web export | Thread support off | Runs on GitHub Pages without special server headers |
| Art | Placeholder PNGs in assets/, loaded as files | v0.2 swaps in the kids' illustrations without code changes |
| Audio | One short chime as an .ogg file | Keeps v0.1 tiny |

Hard rules for Claude Code:

1. Every visual and sound is a file in `assets/`, never drawn in code. This is the deliberate opposite of Block Buddies.
2. The version lives in one place: `application/config/version` in `project.godot`. Everything else reads it.
3. Design for a five-year-old: big targets, no reading, no failure states, unlimited retries.
4. Never commit the Android keystore or its passwords.

## Project structure

One repo, everything in plain text except the art and sound files.

```
cruise-adventure/
  project.godot            # engine settings, version, display, input
  export_presets.cfg       # Web and Android presets (no secrets)
  scenes/
    main.tscn              # the bedroom level
    shirt.tscn             # the draggable item
  scripts/
    main.gd                # success, reset, version stamp
    draggable.gd           # pick up, follow, drop, snap or return
  assets/
    art/                   # bedroom.png, bed.png, suitcase.png, shirt.png, slot.png, check.png, replay.png, star.png
    audio/                 # chime.ogg
  .github/workflows/
    build.yml              # web + Android builds
  CHANGELOG.md
  README.md                # setup, build, install steps
```

`draggable.gd` should be generic (any item, any target slot) because v0.2 adds pants and underwear with the same behavior.

## Build and deploy

One GitHub Actions workflow builds everything in the cloud, so nothing Android-related is installed on the PC. Push to main updates the web build; pushing a version tag also publishes the APK.

1. **Trigger.** On every push to `main`, and on tags matching `v*`.
2. **Environment.** A Godot CI container image (for example `barichello/godot-ci`) pinned to the same Godot version as the editor. It ships Godot headless, export templates, the Android SDK and a JDK.
3. **Import.** Run Godot headless once to import assets before exporting.
4. **Web export.** Export the Web preset to `build/web/`, then publish it to GitHub Pages with the official Pages actions.
5. **Android export.** Decode the keystore from the `ANDROID_KEYSTORE_BASE64` secret to a temp file, pass it to Godot through its environment variables (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`, `_PASSWORD`), and export a signed release APK.
6. **Release.** On a `v*` tag, create a GitHub Release named after the tag with the APK attached as `cruise-adventure-vX.Y.Z.apk`. On plain pushes, keep the APK as a downloadable workflow artifact.

The web build plays at `https://polarispixels.github.io/cruise-adventure/` once Pages is enabled.

## Installing on the tablet and versioning

The tablet installs the APK straight from the GitHub Releases page; no app store is involved.

1. On the tablet, open the repo's Releases page in Chrome and tap the APK.
2. The first time, Android asks to allow installs from Chrome. Allow it. On an Amazon Fire tablet the setting is under Security, "Apps from unknown sources."
3. The game appears on the home screen as "Cruise Adventure."
4. Later versions install over the old one, as long as every build is signed with the same keystore.

Versioning follows Block Buddies' SEMVER habit:

- `application/config/version` in `project.godot` holds the human version (0.1.0).
- The Android `version/code` in the export preset is an integer that must go up by one every release (1 for 0.1.0, 2 for the next). Android refuses an update with the same or a lower code.
- Each release gets a `CHANGELOG.md` entry and a matching `vX.Y.Z` git tag.

## One-time setup for Ryan

About 30 minutes, most of which Claude Code can walk through or script.

- [ ] Create the GitHub repo `polarispixels/cruise-adventure` and open it as a Claude Code project
- [ ] Generate a release keystore once (Claude Code can run the `keytool` command) and store it as repo secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`
- [ ] Back up the keystore file and password somewhere safe. Losing it means the tablet can never update the installed game without uninstalling first
- [ ] In repo Settings, set Pages to deploy from GitHub Actions
- [ ] Optional: install the same Godot version on the PC to open scenes visually
- [ ] Push, tag `v0.1.0`, and install the APK on the tablet

## Out of scope and what comes next

Not in v0.1: TV support, app stores, character art, Jack-Jack or Becca on screen, music, save data, more than one item.

The likely v0.2 adds the kids' illustrated parts sheets rigged in Godot, the dresser drawer, three items (shirt, pants, underwear), the rolling step from the packing video, and zipping the suitcase as the level's finish.
