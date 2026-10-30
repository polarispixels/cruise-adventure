# Cruise Adventure v0.2 - Design

Builds on v0.1 (shipped 2026-10-29 as `v0.1.0`; see `2026-10-29-cruise-adventure-v0.1-design.md`). Every v0.1 constraint still applies unless this document changes it: Godot 4.7.2 GDScript, Compatibility renderer, 1920 x 1080 canvas_items/expand, sensor landscape, one input path through emulated mouse, every visual and sound a file in `assets/`, the version only in `application/config/version`, no keystore in the repo, the same CI and release flow.

## Intent

v0.1 proved the pipeline. v0.2 makes it **feel like Jack-Jack and Becca's game**. The kids see their cartoon selves, in their own rooms, with their own suitcase and picture card, practicing the routine from the family packing video: **Look, Find, Pack, Check.** The goal Ryan cares about is the kids recognizing themselves and cheering each other on, with the real-life skill (follow your card to pack your own suitcase) underneath.

## Players

- **Jack-Jack (6)** and **Becca (4)**. Becca can't read. Nothing in the game may require reading. Text is allowed only as decoration or for grown-ups, and every instruction is a picture, motion or spoken line.
- **Difficulty follows the chosen child.** Playing as Becca is always the easier version; playing as Jack-Jack is a little harder. This is a permanent theme for every later puzzle (Ryan's decision). It's implemented as per-child settings, not separate code paths.

## The experience

### 1. Title screen
- Background: Jack-Jack's room (`Game Assets/Backgrounds/Jack Room - Empty Background v0.1`).
- The game title is at the top, with **"Who do you want to play as?"** written beneath it and also **spoken aloud** (see Audio).
- **Both kids stand full-body on the rug**, taking turns waving (idle -> wave-1/wave-2 flip-book -> idle, a few seconds apart, never both at once).
- **Each whole child plus a colored name ribbon** (blue Jack-Jack, pink Becca) is one big button. Tapping a child plays their `cheer` pose, then transitions to that child's room.

### 1b. Intro video (per child)
After a child is picked, a **short intro clip** plays full screen: the chosen child talks to the player ("We're going on a big ship! Let's pack! Open the drawer and find your clothes! Ready? Let's go!") while the sibling waves. Then the game cuts to the room.
- Source: Ryan's generated clips in `Kids Packing Video/Videos/`. **`becca-pack.mp4`** (10 s, 1280 x 720, 24 fps, H.264 + AAC) is accepted for Becca as is. Ryan's bar is that the characters are recognizable; cosmetic differences from the game art are fine. A Jack-Jack clip will follow. Until it exists, Jack-Jack's path skips straight to the room.
- **Tap anywhere to skip.** The clip never blocks play.
- Godot plays only **Ogg Theora (.ogv)**, so the builder converts each clip (with ffmpeg, keeping 720p and the audio) as part of the art import. Video, like art, is a file in `assets/` and can be swapped without code changes.
- **Risk to verify early in the plan:** smooth playback of a 720p Theora clip on Ryan's Fire tablet (Fire OS 8) and in the web build. If it stutters, re-encode at a lower resolution or bitrate before giving up on video.

### 2. Room (one scene, configured per child)
The chosen child's room (Jack-Jack's or Becca's background). On screen:
- **The player child** stands beside the suitcase. They are the player's on-screen self and react (cheer on each success).
- **The other sibling** stands nearby as **the helper**: they clap and cheer on successes, and if the player does nothing for about 6 seconds, they **point** toward the next thing to tap (suitcase, dresser, item pile, zipper).
- **The suitcase** (the child's own: blue or pink) is closed on the rug.

Sequence:
1. **Open the suitcase.** The player taps the closed suitcase and it pops open. **Their picture card is inside.** It lifts out and settles in a corner of the screen, where it stays as the guide. (In real life the card lives with the suitcase.)
2. **Open the drawer.** The player taps the dresser. A drawer slides open, then the view **zooms into the drawer close-up** (see Find).
3. **Look -> Find -> Pack -> Check, once per item**, for the four items in the card's first row, in card order: **shirt, shorts, underwear, socks.**
   - *Look:* the current item's picture on the card glows.
   - *Find:* the drawer close-up matching game (below).
   - *Pack:* back in the room, the found item flies onto the rug in front of the suitcase, where the four items stack into a flat layup.
   - *Check:* a green check stamps onto that picture on the card, with a chime. The player child cheers and the helper claps.
4. **Roll it.** When all four are checked, the stacked layup glows. The player swipes or taps it and it **rolls into the outfit "burrito" bundle**, as in the video.
5. **Pack the bundle.** The player drags the bundle into the open suitcase, where it tucks in between the suitcase's back and front layers.
6. **Close and zip.** The player taps the lid to close it, then **drags the zipper pull along the zipper** from one end to the other.
7. **Finish.** Big celebration: both kids cheer, plus stars and a chime. Two big buttons appear: **replay** (circular arrow, same child again) and **home** (back to the title screen to switch child).

### 3. Find: the drawer matching game
- A **separate close-up scene** of the open drawer interior (its own background).
- At the top, **the target picture** is shown big, the same picture as on the child's card, inside a dashed outline slot.
- Laid out in the drawer: the target item plus **distractors**, which are other versions of the same kind of item (e.g., the red shirt among yellow, blue and green shirts).
- The player **drags the matching item onto the target picture**. The match snaps in, then the view zooms back out to the room, where Pack happens.
- **A wrong item** wiggles and slides back to its spot. There's no failure sound, penalty or counter. After 2 wrong tries, the helper sibling (shown small in a corner of the close-up) points at the right item.
- Item positions are shuffled each time.

### Difficulty settings (v0.2 values)
| Setting | Becca | Jack-Jack |
| --- | --- | --- |
| Choices in the drawer | **2** (target + 1) | **4** (target + 3) |
| Distractor style | obviously different color from the target | other colors, can be closer to the target's |
| Helper idle hint delay | 6 s | 8 s |

Distractors are color variants of that child's own item (see the art requests). The settings live in data, one file per child, which also holds that child's room, suitcase, card, items and helper. Harder future puzzles (stripes vs. solid, long vs. short sleeves, three dots vs. four) are **out of scope for v0.2** but must fit as new art plus data, with no new code.

## Goals
- Title screen, room, drawer close-up and finish, as above, for **both children**.
- The difficulty difference between Becca and Jack-Jack, driven by data.
- Integration of Ryan's art from the packing-video project (pipeline below), with placeholders standing in until each piece arrives.
- Release `v0.2.0` through the existing pipeline, installed over v0.1 on the Fire tablet.

## Non-goals (v0.2)
Patterned or "spot the difference" puzzles, card rows 2-4 (pajamas, swimsuit, and so on), music, save data or progress tracking, scores, timers, a third scene beyond the room and drawer, Ryan recording the voice lines (a placeholder voice is fine), skeletal or rigged character animation, TV support and app stores.

## Anti-goals (a failure even if it technically works)
- Anything that needs reading to proceed, or any instruction given only as text.
- Failure states: "wrong" sounds, lives, timers, losing progress, red X's.
- Becca's version being too hard to finish alone.
- Characters that jitter or shift when switching poses (bad alignment), visible halos or painted backgrounds around cut-outs, or characters that look off-model compared with the approved sheets.
- Rebuilding the puzzle system per child or per item instead of driving it from data.
- Breaking in-place updates: `version/code` must go to **2** and the APK must be signed with the same keystore.

## Art pipeline
- Ryan makes the art in the packing-video project, in `C:\Users\rgris\Documents\ChatGPT\Kids Packing Video\Game Assets\`, using the specs in `docs/art/v0.2-art-requests.md` (characters, rooms, suitcases, clothing, drawer, UI). **The builder only reads that folder. It never writes to it.**
- The builder copies approved files into `assets/` under stable game names (e.g., `assets/characters/becca/cheer.png`) with a small import script and a manifest, so new art versions are a re-import with no code changes.
- **Until a piece of real art exists, the game uses a placeholder with exactly the same canvas size and registration as the spec**, so swapping in real art is a pure file replacement. Placeholders can be generated like v0.1's, or be rough crops from the approved sheets, clearly marked provisional.
- Only art Ryan has accepted gets imported into a release build. Files marked `PROVISIONAL` are fine for development and test builds.

## Audio
- Keep the v0.1 chime for successes.
- **Spoken lines are required** wherever the game would otherwise need reading. At minimum: "Who do you want to play as?" on the title screen. Nice to have: the child's name on tap ("Jack-Jack!", "Becca!"), and a short cheer on finish.
- v0.2 may ship with **placeholder synthesized voice files**. Swapping in recordings later (possibly Ryan's voice, as in the packing video) is just a file replacement.

## Constraints and settled facts
- Character art comes as **whole-body pose cut-outs** (idle, wave-1, wave-2, cheer, clap, point) on an identical 1024 x 1536 canvas per child, feet on y = 1480 and centered at x = 512. Animation means **swapping poses** plus code-driven bounce, squash and tilt. All poses face the viewer's right. **The game mirrors a character** when they need to face the other way.
- **Both rooms share one layout** (dresser left, window center, bed right, rug center), so positions are shared and only textures change per child.
- Backgrounds are 16:9 and may be smaller than 1920 x 1080 (Jack-Jack's is 1672 x 941). The game **scales a background to cover** the visible area and keeps the outer 6% at the sides decorative.
- Each child's card art comes from the packing-video project's video cards (`Production Docs/Video Card - Jack v0.2.png`, `Video Card - Rebecca v0.2.png`, 1200 x 1600, 4 x 4 grid, row 1 = shirt/shorts/underwear/socks). Checkbox positions for stamping come from that project's verification data or are measured once.

## Builder's calls (not agreed with Ryan; flagged for review)
1. **In Find, you drag the match onto a big target picture** instead of dragging it across scenes into the suitcase.
2. **Found items stack on the rug first, and the bundle is packed after rolling.** This follows the video's order (roll, then pack). It means the suitcase stays empty until the bundle goes in, which differs slightly from the earlier chat description where each item dropped straight into the suitcase.
3. **The zip is a drag along the zipper.** Close the lid with a tap, then drag the pull left to right.
4. **The finish screen has replay and home buttons.** Home returns to the title to switch child.
5. **The card shows all 16 pictures in a corner.** Rows 2-4 are dimmed for future levels, and the current picture glows.
6. **Helper hint timings:** 6 s for Becca and 8 s for Jack-Jack; after 2 misses in Find, the helper points.
7. **A placeholder synthesized voice** for the remaining spoken lines (e.g., "Who do you want to play as?") until recordings exist. The intro videos carry their own voices.
8. **Title background:** Jack-Jack's room for now (Becca's room could alternate later).
9. **The dresser is tapped once.** After each Check, the game goes back into the drawer close-up by itself after a short beat (about 1 s) for the next item. The child taps the dresser only for the first item. That keeps the pace up for Becca.
10. **Who makes the color variants:** Ryan's art agent, per the updated Request 3 in `docs/art/v0.2-art-requests.md`. (The copy in `Game Assets/` predates the variants; Ryan sends the update.) Until they arrive, the builder makes **placeholder** variants by recoloring the card item in a script. They're marked provisional and replaced as files arrive.

## Answered by Ryan
- **Release gating:** provisional art is fine in development and test builds (pushes to `main`: web and test APK). The **`v0.2.0` tag waits until Ryan has approved the art** in it. Approval is recorded in the art project's status file or by Ryan telling the builder. The import manifest flags anything still provisional, and a release build refuses it.
- **The art bar is MVP:** recognizable characters are enough. Don't hold anything back for cosmetic continuity.

## Left to the builder
Scene and file structure, the data format for per-child settings, tween and timing details, exact on-screen positions within the shared layout, transitions between scenes, the import script and manifest format, the placeholder generation method, and test design (following v0.1's headless runner and real-input tests).

## Additions from playtest 1 (Ryan, 2026-10-29)

Ryan played both kids on the Fire tablet. The intro videos play well. At one point Becca didn't know what to do next.

1. **Pulsing cues.** The thing to do next pulses until the child does it: the suitcase (open, and later close), a glow over the dresser, the pile on the rug, the bundle, and the zipper pull.
2. **Done video.** After zipping and the cheer, `Videos/becca-done.mp4` plays full screen (tap to skip), then the replay/home buttons. Jack-Jack uses the same clip until `jack-done.mp4` exists. A missing clip goes straight to the buttons.
3. **Several outfits.** Jack-Jack rolls six outfits; Becca rolls four (Ryan: six is probably long for her, "3 or 4"). One outfit = tap the dresser, find shirt/shorts/underwear/socks, tap the pile to roll it, drag the bundle into the suitcase. The card's checks clear for the next outfit, and the packed bundles stay visible in the suitcase as progress. After the last one: close and zip. The outfit count is per-kid data (`KidProfile.outfits`).
4. **More colors, randomized.** Every item comes in 8 colors (the card's color plus 7 hue shifts, 45° apart). Each outfit picks the colors at random: the item to find is a random color, shown in the picture above the drawer. Becca's distractor is always at least 135° away in hue; Jack-Jack's are any other colors (`KidProfile.min_color_gap`).
