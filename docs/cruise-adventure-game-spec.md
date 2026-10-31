# Cruise Adventure Game Spec (Provisional)

Oct 29, 2026 · Ryan Grissinger (director)

> **This file is the source of truth for the overall game.** Edit it here. Release-level designs and plans live in `docs/superpowers/` and must agree with it. Other places that mention this spec (the claude.ai Vacation project, chat drafts) only point here.

## Overview

Jack-Jack and Becca's Cruise Adventure is now the core product: an interactive game for the Fire tablet and the web, where the kids play through the same story the packing video was going to tell. Video becomes short segments inside the game (intros, reactions, payoffs), not a standalone 3-minute film.

The story, routine and takeaway carry over unchanged from Packing Video Storyboard v0.2: a mission, the routine **Look, Find, Pack, Check**, a mistake to fix, and a payoff on the ship. The takeaway stays "I have a card. I follow it. I can do it myself." The difference is that the child does each step with their own finger instead of watching it.

This spec sits above the existing v0.2 game design in the repo. It sets the overall structure; each release still gets its own detailed design and plan.

## Team roles

Four roles have settled in. Ryan approves everything that ships, and each agent works only in its own folder.

| Role | Who | Owns | Works in | Hands off |
| --- | --- | --- | --- | --- |
| Director | Ryan with Claude (chat) | Story, chapter plans, this spec, priorities, approvals | This file, specs in `docs/` | Design docs and requests to the other three |
| Developer | Claude Code | Godot game code, tests, import tools, builds, releases | `polarispixels/cruise-adventure` | Playable builds (web link, APK), art and video requests |
| Designer | ChatGPT | Characters, rooms, props, cards, UI art | `Kids Packing Video/Game Assets/`, `Production Docs/` | Approved PNGs plus status and handoff notes |
| Video specialist | Gemini (plus Runway for tests) | Video segments with the kids' voices | `Kids Packing Video/Videos/` | MP4 clips named per the video requests |

Rules that keep the handoffs clean:

1. **One source of truth per thing.** The story lives in this spec, art in `Game Assets/`, video in `Videos/`, code in the repo. Nobody copies a decision into a second place without linking back.
2. **Requests are documents.** The developer writes art and video requests into the repo (`docs/art/`, `docs/video/`). Ryan carries them to ChatGPT or Gemini.
3. **The developer only reads the art and video folders.** It copies approved files into `assets/` through the import script and never edits the originals.
4. **Provisional is fine until release.** Anything unapproved can appear in test builds. A version tag waits for Ryan's approval of the art and video in it.
5. **The character sheets win.** Every agent works from Character Sheets v0.4 (Becca's eyes are brown; Jack-Jack's hair is golden sandy dirty-blonde, no copper or orange, as Ryan decided on October 31, 2026).
6. **Gemini's budget is the scarcest resource.** On the current plan it produces about 4 clips every 5 hours. Video requests are ranked by priority, and clips the developer needs to unblock a release come first.

## Story arc

Part 1 is the storyboard's six chapters turned into play. Part 2 is the trip itself, which the video never covered. Storyboard panel numbers are in brackets.

### Part 1: Packing

| Chapter | Video segments | What the child plays | It teaches |
| --- | --- | --- | --- |
| 1. The mission [1-3] | Optional VHS title bumper; the kids see the cruise ship poster; each holds up their card | Title screen: pick Jack-Jack or Becca. The suitcase opens and the card pops out | "This is my card" |
| 2. The routine [4-6] | The chosen child's intro (`becca-pack.mp4` exists) | Row 1: shirt, shorts, underwear, socks through Look, Find, Pack, Check; roll the burrito; pack it; zip (this is the v0.2 design) | The routine and the bundle |
| 3. Your turn [7-13] | Short "what's next?" prompts (`*-level2.mp4`); the sibling miming swimming | Rows 2-4 of the card, a row at a time. Counting six bundles with Becca | Following the card alone |
| 4. Uh oh [14-16] | Jack-Jack sitting on his overflowing suitcase; Becca holding four swimsuits | **Spot and fix the mistake.** Jack-Jack's path: drag the extra toys back to the shelf until the lid closes. Becca's path: compare the suitcase to the card, put back three swimsuits, find the missing underwear | Checking the card fixes mistakes |
| 5. Inspection [17] | Dad stamps the cards APPROVED | Hand the card to Dad. Every check lights up, then the stamp | Done means checked |
| 6. Payoff [18] | The kids at the pool in swimsuits and in pajamas in the cabin | Tap the packed items to "use" them on the ship | Packing pays off |

**October 30, 2026 decision:** packing (chapters 1-3) is complete. Chapters 4 (Uh oh) and 5 (Inspection) are dropped. Chapter 6's pool-and-cabin payoff moves to arrival at the ship (chapters 10-11), so the journey stays in order.

### Part 2: The trip

| Chapter | Video segments | What the child plays | It teaches |
| --- | --- | --- | --- |
| 7. To the car | Pushing suitcases into the car (the Runway clip exists) | Load suitcases and booster seats in the right spots | Getting ready to leave |
| 8. The airport | Walking through the airport (the Gemini clip exists) | Follow picture signs to the gate; put the bag on the security belt | What the airport is like |
| 9. The flight | Takeoff out the window | Calm activities in the seat: buckle up, pick a snack, look out the window | What flying is like |
| 10. The ship | Boarding the ship | Find the stateroom by matching the key card number to the doors | Numbers and finding your way |
| 11. Ship and beach | Water slides, the beach | A playground of mini games that grows over time | Fun, and the reason for all the work |

Part 2 can use real photos and memories from the trip to shape each chapter.

**Chapter specs.** Chapter specs now live in the Kids Packing Video `Specs\` folder, one per chapter, each built from `Cruise Adventure - Chapter Spec Template.md`. A chapter spec holds the detail: the play segments, what's different for Jack-Jack and Becca, art, video, voice lines and an acceptance checklist. This spec keeps the structure and the rules, and wins if the two disagree. The project page's checklist for a chapter follows its spec's acceptance checklist.

- Chapter 8, The airport: [Cruise Adventure - Chapter 08 - The Airport v0.1.md](file:///C:/Users/rgris/Documents/ChatGPT/Kids%20Packing%20Video/Specs/Cruise%20Adventure%20-%20Chapter%2008%20-%20The%20Airport%20v0.1.md) (`Kids Packing Video\Specs\`). Ryan approved it on October 31, 2026. It has three play segments: Goodbye suitcases, Through security and Find our gate.

**October 31, 2026 decisions:**

- **The family SUV is black,** as in Art Round 5. This supersedes the teal SUV in the game storyboard's keyframes 02-04, which will be corrected when those frames are revised. The car intro clip (`ready-to-pack-the-car.mp4`) also shows the teal car.
- **The trip-wide bag plan is approved.** It's in section 3 of the chapter 8 spec, and later chapters follow it.
  - Jack-Jack's blue suitcase, Becca's pink suitcase and Mommy's yellow duffel are checked at the airport and next appear at baggage claim.
  - Daddy's gray suitcase is his carry-on, and goes in the overhead bin in chapter 9.
  - The kids' backpacks are their activity bags, holding the tablet and buddy for the flight.
  - Daddy's backpack and Mommy's purse are carry-ons.
- **Jack-Jack's hair is golden sandy dirty-blonde, no copper or orange.** Character Sheets v0.4 still win.

## Segment pattern and design rules

Every chapter follows the same loop: **video intro, play, video payoff**, then on to the next chapter. The developer builds this once as a reusable segment player ("play this clip, then go to this scene") driven by a data file listing the chapters in order. Adding a chapter means adding clips, art and one entry, not new plumbing.

Rules for video segments:

1. **8 to 10 seconds, never longer than 15.** Video is the reward and the instruction, not the main event.
2. **Always skippable** with a tap. A child who has seen it ten times shouldn't have to wait.
3. **Spoken, never written.** The kids explain what to do out loud; no captions.
4. **Held still frame at the start and end** (half a second each) so cuts into and out of the game are clean.
5. **One clip per child where the lead changes.** Jack-Jack's path plays his clips, Becca's plays hers.
6. **The retro training-film wrapper stays light.** Dad's deadpan voice and the VHS bumper are for the grown-ups and can appear at chapter edges, but the kids carry the instructions.

Rules for play segments (carried over from v0.2):

1. **No reading required.** Every instruction is a picture, a motion or a spoken line.
2. **No failure states.** No wrong sounds, lives, timers or lost progress. Mistakes wiggle and slide back.
3. **Becca's version is always easier**, set by per-child data, never separate code.
4. **The sibling is always the helper**, cheering and pointing when the player is stuck.
5. **The real card is the game card.** The same 4 x 4 picture card the kids use on packing day.

## Release roadmap

The trip leaves November 10. The goal is a playable Chapter 2 before then, so the kids practice packing in the game and then pack for real. Everything after that is no-pressure.

| Version | Contents | Target | Waiting on |
| --- | --- | --- | --- |
| 0.1 | Drag the shirt into the suitcase (pipeline proof) | Shipped Oct 29 | Nothing |
| 0.2 | Chapters 1-2: pick a child, intro video, row 1, roll, pack, zip | Before Nov 10 | Developer build; `jack-pack.mp4`; video plays smoothly on the Fire tablet |
| 0.3 | Chapter 3: rows 2-4, counting six bundles, the segment player as a reusable system | After the trip | Art round 2 (rows 2-4, hmm and hug poses); level-2 clips |
| ~~0.4~~ | ~~Chapters 4-6: the mistake, inspection, the ship payoff~~ | Dropped Oct 30 | Packing is complete; the payoff moves to the ship |
| 0.4 | Chapter 7, To the car: the trunk puzzle first, then a checkpoint to decide what follows | Next | Trunk puzzle design; car and trunk art |
| 0.5+ | The rest of the journey, one stop per release. The expanded stops (baggage claim and rental car, hotel and beach) are proposed in `Specs/Cruise Adventure - Game Story Arc v0.2.md` | Ongoing | Trip photos and memories, new art and clips per chapter |

The first developer task in 0.2 stays the video check on the Fire tablet. If 720p Theora stutters there, every later chapter needs lower-resolution clips, so it's worth knowing on day one.

## Open questions for Ryan

- [ ] Is the 3-minute packing video retired, or still wanted later as a separate cut assembled from the game's clips?
- [ ] Does Dad's narration (the training-film voice) stay in the game, and is it your recorded voice or a placeholder?
- [x] ~~Chapter 4: one mistake per child, or both?~~ Moot: chapter 4 dropped Oct 30.
- [ ] Is a playable Chapter 2 before November 10 the real target, or a nice-to-have?
- [ ] Should the packing-video project's paused storyboard tasks (3 and 4) be closed out in favor of this spec, so ChatGPT stops waiting on them?
