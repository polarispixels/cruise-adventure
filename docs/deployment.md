# Deploying Cruise Adventure

How work gets from the repo to a browser, the Fire tablet, and the live project page. There are four routes. They differ in who sees the result and whether Ryan has to say yes.

| Route | What it updates | When | Ryan's OK |
| --- | --- | --- | --- |
| 1. Local preview | `http://localhost:8060` on this computer | Any time, while building | No |
| 2. Playtest | A tablet APK, published as a GitHub **pre-release** | Every checkpoint | No |
| 3. Merge to main | The live browser game and the live project page (`/docs/`) | Every checkpoint, right after the playtest | No (pre-approved Oct 31, 2026) |
| 4. Version release | The official APK release (`vX.Y.Z`) | When Ryan says a version is done | **Yes** |

Links:

- Live game: https://polarispixels.github.io/cruise-adventure/
- Project page: https://polarispixels.github.io/cruise-adventure/docs/
- Releases (playtests and versions): https://github.com/polarispixels/cruise-adventure/releases

## What's a checkpoint

Work happens on a version branch (for example `v0.4`), one feature at a time: design, plan, build. A **checkpoint** is the point where a feature is ready for the kids to try. It's reached when all three are true:

- all tests pass: `tools/godot.sh --headless --script res://tests/run_tests.gd` and `python3 -m unittest discover -s tests -p "test_*.py"`;
- the fresh whole-branch code review has been done and its Critical and Important findings are fixed, each with a test;
- the web build has been played locally (route 1).

At a checkpoint, do routes 2 and 3, in that order.

## 1. Local preview

```bash
mkdir -p build/web && tools/godot.sh --headless --export-release "Web" build/web/index.html
python3 -m http.server 8060 -d build/web     # if it isn't already running
```

Refresh http://localhost:8060. Progress lives in the browser; hold the version number on the title screen for 5 seconds to reset it.

For a scene deep in the game (for example the trunk, which needs a finished card), it's fine to make a throwaway copy of the project whose main scene jumps straight there, and serve it on another port. Never commit that.

## 2. Playtest (tablet)

```bash
git push                                              # the version branch
gh workflow run build.yml --ref v0.4                  # tests, web build, signed APK
gh run watch <run id> --exit-status
gh run download <run id> -n android-apk -D <tmp dir>
gh release create playtest-v0.4-N <tmp dir>/*.apk --prerelease --target v0.4 \
  --title "Playtest v0.4-N" --notes "<one line: what to try>"
```

Number playtests per version: `playtest-v0.4-1`, `-2`, and so on. On the tablet, open the pre-release page in Silk and tap the APK. It installs over the old one, because every build is signed with the same key. A pre-release never becomes "latest", so the official release link is unaffected.

## 3. Merge to main (live game and project page)

```bash
gh pr create --base main --head v0.4 --title "<checkpoint>" --body "<what's in it>"
gh pr merge --merge --delete-branch=false
gh run watch <the main run> --exit-status             # test, web, pages, deploy-pages
```

The `pages` job builds the project page from `docs/site/story.json` into `/docs/` next to the game, and runs its tests first. The page's checklists tick themselves from what's in the repo: files present, voice lines recorded, card rows playable. So **before merging, update `docs/site/story.json`** for anything that can't tick itself: mark hand-ticked items `"done": true`, add new chapters or checks, and drop finished or abandoned ones. If new keyframes or clips arrived, run `python3 tools/make_docs_images.py` and commit `docs/site/img/`.

After the deploy, open the project page and check the new state shows (the footer names the commit it was built from).

Keep the version branch going after the merge. The next checkpoint merges again.

## 4. Version release (official)

Only when Ryan says a version is done. The steps are in the README's [Make a release](../README.md#make-a-release) section: approve the art, bump `config/version` and `version/code`, write the CHANGELOG entry, merge, then tag `vX.Y.Z` on `main`.

The tag build refuses to publish while any art in `data/art_manifest.json` is unapproved. Stand-ins count as unapproved: the trunk stand-ins are `approved: false` until art round 5 arrives.

## Bringing in art, video and voice

The art, video and voice agents deliver into the Kids Packing Video folder. This repo only reads from that folder. The one exception is request documents, which go into its `Specs\` folder. Ryan doesn't need to approve art before it's imported.

| Delivery | Where it lands | What to run here |
| --- | --- | --- |
| Art (PNGs) | `Game Assets\...` | Point its `data/art_manifest.json` entry at the file (`"generator": "copy"`, `"source"`, `"approved": true`), then `python3 tools/import_art.py` and `tools/godot.sh --headless --import` |
| Video (MP4) | `Videos\` | Add a `"generator": "video"` manifest entry (`assets/video/<name>.ogv`), then the same two commands |
| Voice (m4a, any name) | Uploaded in chat | Copy to `recordings/<jack\|becca\|shared>/<line id>.m4a`, then `python3 tools/import_voice.py` |

Then run the tests and preview locally. The next checkpoint ships it.

New requests for the agents go into the repo (`docs/art/`, `docs/video/`, `docs/voice/`), with a copy in `Kids Packing Video\Specs\`.

## Never

- Commit the Android keystore or its password. The keystore lives in `~/keystores/cruise-adventure/`, with a backup on `F:\backups\keystores\cruise-adventure\`.
- Write anywhere in the Kids Packing Video folder except `Specs\`.
- Tag a version without Ryan's OK.
