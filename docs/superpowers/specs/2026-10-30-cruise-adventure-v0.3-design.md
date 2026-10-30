# Cruise Adventure v0.3 Design: Pack the Whole Card

**Status:** draft for Ryan's review (2026-10-30)
**Builds on:** v0.2 (`2026-10-29-cruise-adventure-v0.2-design.md`, including its playtest additions)

## Why

v0.2 packs only row 1 of the picture card. The kids' cards have four rows, and the art for rows 2–4 has been delivered (art round 2). v0.3 lets each child pack their whole card, one row per level. It also gives the game a voice: a 4-year-old can't read, and so far the only spoken line is the robotic title question.

## Goals

- Four levels, one per card row, for both kids, with the same per-kid difficulty rules as v0.2 (Becca easier, Jack-Jack harder, all from `KidProfile` data).
- **The card is the level map.** After picking a kid, the child sees their own card, full screen. The next row to play pulses. Finished rows get a big check. A finished row can be replayed by tapping it.
- **Progress is saved** on the device per kid, so tomorrow the card shows what's already packed.
- **Spoken instructions and cheers** for every step, said by the helper sibling (the one who points), with the item names ("Find your pajamas!").
- Reuse the v0.2 engine: room, drawer game, cues, card, done video. Each level is mostly data.

## Non-goals

- The trip itself (car, airport, ship). That's v0.4, which the new airport and vehicle videos point toward.
- New mechanics beyond what's listed. No timers, scores, failure sounds or reading.
- Polishing v0.2 art.

## Anti-goals

- A child getting stuck on the map, not knowing what to tap. The next row must always pulse, and the helper says what to do.
- Losing progress, for example when the tablet restarts.

## The levels

| Level | Card row | Find it in | After finding |
| --- | --- | --- | --- |
| 1 | shirt, shorts, underwear, socks | dresser drawer | roll into a bundle, pack (v0.2: Becca 4 outfits, Jack-Jack 6) |
| 2 | pajamas, swimsuit, hoodie, nice outfit | dresser drawer | roll into a bundle, pack. 1 round |
| 3 | sandals, hat, hairbrush, toothbrush | **closet basket** (new prop on the floor) | not rolled. Each found item lands on the rug, then the child drags each one into the suitcase |
| 4 | buddy, book, tablet, special toy | **toy box** (new prop on the floor) | like level 3. Before the buddy goes in, the player's kid **hugs** it (hug pose) |

- Each level ends with close lid, zip and the done video, then returns to the card map with the new row checked. After the 4th row there's a big celebration (the done video plus stars). A "whole card" video can replace it later.
- Distractors stay data-driven. Every item comes in 8 hue variants made by the import script, with the v0.2 rule: Becca's wrong choice is far away in hue, Jack-Jack's can be close. Items whose recolor looks wrong (e.g. the buddy) are listed in the manifest as color-locked. For those, the distractors are *other items from the same row*, which suits both kids.
- The suitcase keeps everything packed in earlier levels in the same session (a row of small icons along the suitcase rim is enough). It isn't stored between sessions.

## Voices

The helper sibling speaks: instructions on each step (with a short delay so the pulse comes first), "You found it!" and similar cheers, a gentle "Hmm, try another one!" on a miss (with the "hmm" pose), and the item name on every find. Lines are short audio files in `assets/voice/<kid>/<line-id>.ogg`, listed in a manifest like the art. Missing lines fall back to the robotic placeholder, so the game never waits on recordings.

The line list is in `docs/voice/voice-lines-v0.3.md`.

## The builder's calls (Ryan can overrule)

1. The card as the map, instead of a separate map screen. No new art needed, and the kids already know the card.
2. The kid intro video plays the first time only. After that, picking a kid goes straight to the card.
3. Level order: rows unlock in order, and the next one pulses. Finished rows can be replayed any time.
4. Save file: `user://progress.json` holds `{kid: {levels_done: [..]}}`. A long press on the title's version stamp clears it, for grown-ups.
5. Level 1 keeps v0.2's outfit counts. Levels 2–4 are one round each.
6. Multi-agent build: levels and pieces with clear interfaces go to smaller agents, and the coupled work stays with the lead, followed by one strong final review.

## Questions for Ryan

- Who voices the lines? (see the voice doc)
