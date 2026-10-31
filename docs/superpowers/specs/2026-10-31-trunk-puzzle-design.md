# Trunk Puzzle Design (Chapter 7, To the car, part 1)

Oct 31, 2026 · Ryan (director), Claude (developer)

## Why

Packing (chapters 1-3) is finished and works on the tablet. On October 30 Ryan shifted the game from "finish the packing story" to "the whole journey, one stop at a time": pack, car, airport, flight, arrival, hotel and beach, ship. Chapters 4-5 are dropped and the ship payoff moves to the ship. The overall game spec has the decision; `Kids Packing Video/Specs/Cruise Adventure - Game Story Arc v0.2.md` has the proposed journey.

The first new stop is loading the car. Ryan's call: **build the trunk puzzle, then stop at a checkpoint** (play it on the tablet with the kids, then decide what's next) before buckling up, driving or the airport.

Success is Jack-Jack and Becca loading the family's real bags into a cartoon version of the family's black SUV, needing to turn some bags on their side to make everything fit, and feeling clever when the hatch closes.

## Goals

- A new scene where the child drags all of the family's bags from the driveway into the open trunk of a black SUV, turning some on their side to make them fit, then closes the hatch.
- The real family's bags (Ryan's list):
  - Jack-Jack's blue suitcase
  - Becca's pink suitcase
  - Mommy's big yellow bag
  - Daddy's medium gray bag
  - Mommy's black purse
  - Daddy's black backpack
  - Jack-Jack's gray and black monster-truck backpack
  - Becca's pink backpack
- **Everything goes in the trunk, backpacks too** (Ryan).
- **Turning is part of the puzzle**: the bags lie on the ground standing up, and some must be turned to fit (Ryan).
- The chapter loop carries over: intro clip, play, payoff clip, the finish buttons.
- Becca's version is easier, set by data, not separate code.
- The sibling helps, talking (recorded voice lines) and pointing when the child is stuck.

## Non-goals (after the checkpoint, if at all)

- Buckling up, the drive, the journey map, the airport.
- Booster seats.
- Free (non-grid) placement or physics.
- Dad's or Mom's voice.

## Anti-goals

- A puzzle that can dead-end with no way out. The child must always be able to take a bag back out.
- Anything that feels like failure: no wrong sound, no timer, no lives. A bag that doesn't fit slides back to the driveway.
- Needing to read.

## The puzzle (decided)

**The trunk** is an invisible grid **7 cells wide x 5 tall**, seen from behind through the open hatch. The bottom-left and bottom-right cells are **wheel-well bumps** and are blocked.

**The bags** are rectangles of cells, in their standing ("on the driveway") orientation:

| Bag id | Owner | Cells (w x h) |
| --- | --- | --- |
| `mommy-yellow` | Mommy | 5 x 2 |
| `daddy-gray` | Daddy | 2 x 3 |
| `jack-suitcase` | Jack-Jack | 2 x 2 |
| `becca-suitcase` | Becca | 2 x 2 |
| `daddy-backpack` | Daddy | 2 x 2 |
| `jack-backpack` | Jack-Jack | 1 x 2 |
| `becca-backpack` | Becca | 1 x 2 |
| `mommy-purse` | Mommy | 1 x 1 |

They exactly fill the 33 open cells. A search over all placements found that **no arrangement fills the trunk unless at least one bag is turned**, which gives the "you have to turn it" moment Ryan described. A reference solution (used for hints, and on the art contact sheet):

```
 Y Y Y Y Y J J      Y mommy-yellow    J jack-suitcase     G daddy-gray (turned)
 Y Y Y Y Y J J      B becca-suitcase  d daddy-backpack
 G G G B B d d      j jack-backpack (turned)   b becca-backpack (turned)
 G G G B B d d      p mommy-purse     # wheel well
 # j j b b p #
```

Other complete arrangements may exist; any complete one wins.

**Moves:**
- **Drag a bag into the trunk.** It snaps to the nearest grid spot. If it fits there (inside the grid, not on a wheel well, not overlapping), it stays. If not, it slides back to its place on the driveway.
- **Tap a bag on the driveway** to turn it a quarter turn (standing ⇄ on its side). Two turns get back to the start. The art is drawn once, standing; turning rotates the picture 90 degrees.
- **Drag a bag that's in the trunk** back out (or to another spot) to rearrange. This is the way out of any dead end.

**Turning, in detail** *(developer's calls)*:
- A bag keeps the way it's turned wherever it goes: when it slides back after a drop that doesn't fit, and when it's dragged back out of the trunk. The child's turning is never undone for them.
- Tapping a bag that's in the trunk does nothing but a small wiggle. To turn it, drag it out first.

**Finishing:** when the last bag snaps in, the helper says "Everything's in! Close the trunk!" and the hatch pulses (the same pulse cue the suitcase uses). Tapping it closes the hatch: the closed-SUV picture replaces the open one, with a thunk. Then the helper says "Airport, here we come!", the payoff clip plays, and the finish buttons appear (home, replay, continue).

## Becca's version and Jack-Jack's (data, not code)

- **Becca:** Mommy's yellow bag and Daddy's gray bag start already in the trunk (in their reference-solution spots), **locked** (they can't be dragged out, like the locked toys in row 4), so she loads the other six. *(Developer's call.)* Faint outlines in the trunk show where each remaining bag goes, already turned the right way. If she drops a bag that would fit there turned, it turns itself and snaps in, and the helper says "Tap it to turn it!" so she learns the idea without being stuck on it.
- **Jack-Jack:** all eight bags start on the driveway. There are no outlines. A bag that would fit turned slides back, and the helper says "Tap it to turn it!"

## The helper's hints (both kids)

When the child hasn't placed a bag for a while (the existing cue timing):
1. If the bags already in the trunk can no longer lead to a full trunk, the helper points and the first such bag wiggles. "Hmm... try another spot!"
2. Otherwise one bag on the driveway pulses, and its outline glows where it goes in a full arrangement that agrees with what's already placed. It picks a bag that must be turned in that arrangement if there is one (that's the idea the puzzle teaches), else the biggest bag left. *(Developer's call.)*

Deciding "can this still lead to a full trunk" is a small backtracking search over at most 8 bags on 35 cells, which is instant.

## Where it fits in the game

- When all four rows of the card are packed, the card map shows a new **car** button. Tapping it plays the kid's car intro clip the first time (as row intros do), then the trunk puzzle. *(Developer's call; the journey map comes later.)*
- The finish screen's Continue goes back to the card map, as it does now. Home goes to the title, as always. Finishing the trunk is saved in progress as its own flag per kid (not a fifth row, so "all four rows packed" keeps working), and the long-press reset clears it. *(Developer's call.)*
- Music, voice ducking, the in-game home button and the skippable videos behave as they do in the packing scenes.

## Assets

Requested from the art agent (`docs/art/v0.4-art-requests-round-5.md`, copied to `Kids Packing Video/Specs/`):
- 8 bag PNGs at 200 px per cell, filling their rectangles
- `suv-open.png` and `suv-closed.png` with a 1400 x 1000 cargo rectangle and wheel wells in the bottom corners
- `driveway.png`
- optional "lift" poses

Requested from the video agent (`docs/video/video-requests-round-3.md`):
- `jack-car.mp4` and `becca-car.mp4` (intros)
- `car-drive-off.mp4` (payoff)

Voice (`docs/voice/voice-lines-v0.4.md`): six lines per kid, with fixed ids: `load-car`, `turn-it`, `try-another-spot`, `it-fits`, `close-trunk`, `lets-go`. Recorded cheers are reused.

Until the art arrives, the developer generates stand-ins (colored rounded bags with simple icons, a plain SUV shape) with `tools/make_placeholders.py`, as for earlier rounds, so the puzzle can be built and played first.

## Left to the builder

- Screen layout: where the SUV sits, the on-screen cell size, and each bag's resting spot on the driveway. Everything must be visible at once on a 16:9 and a 16:10 tablet, and every bag at least as big as a fingertip.
- Snap rule details: e.g. snap by the bag's top-left cell nearest the drop point, or by its center.
- The "hasn't placed a bag for a while" timing, reusing the packing cue timer.
- Data format, e.g. `data/trunk.json` with the grid, wheel wells, bags, the reference solution and each kid's settings.

## Checkpoint

When it plays end to end with stand-ins (or real art if it has arrived), ship a playtest APK. Ryan plays it with the kids. Then we decide what's next: real art polish, buckling up, the drive, or straight to the airport.
