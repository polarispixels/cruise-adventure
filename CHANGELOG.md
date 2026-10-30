# Changelog

All notable changes to this project are documented here.

## [0.3.0] - 2026-10-30

Pack the whole card: four levels, one per card row. Includes everything from 0.2.0, which was never released on its own.

- The kid's card is the level map. The next row wiggles, finished rows get a big check, and any finished row can be played again. Progress is saved on the device.
- Row 1 (shirt, shorts, underwear, socks) and row 2 (pajamas, swimsuit, hoodie, nice outfit): find each in the dresser drawer, roll and pack. Row 3 (sandals, hat, hairbrush, toothbrush) is found in the closet basket and row 4 (buddy, book, tablet, special toy) in the toy box; each find lands on the rug to drag into the suitcase, and the buddy gets a hug first.
- Rows 2-4 start with a short video of the two kids the first time; a tap skips it.
- The helper sibling says every instruction and cheer out loud (a computer voice until Jack-Jack and Becca record theirs).
- Packing the whole card gets a bigger celebration.
- Jack-Jack has his own "you did it" video.
- End of a level: Home (title screen), Replay, and a big Continue (back to the card). A home button in the corner leaves a level any time.
- A quiet background tune that dips while the helper talks and pauses for videos.
- Holding the version stamp for 5 seconds clears saved progress (for grown-ups).

## [0.2.0] - not released separately

Jack-Jack and Becca's packing game, with their own art.

- Title screen: both kids wave in Jack-Jack's room and a voice asks "Who do you want to play as?" Tap a kid to pick them.
- Each kid's intro video plays first; a tap skips it.
- Each kid's own room: tap the suitcase to open it and reveal the picture card, then tap the dresser.
- Find game in the open drawer, four times over (shirt, shorts, underwear, socks): drag the matching one onto the picture. Becca chooses from 2, Jack-Jack from 4. A wrong pick wiggles back; after two misses the other kid points to the right one.
- Each find flies to the rug, gets a check on the card, and both kids celebrate.
- Tap the pile to roll it into a bundle and drag it into the suitcase. That's one outfit: Becca packs 4 outfits, Jack-Jack 6, and the bundles pile up in the suitcase.
- Every piece of clothing comes in 8 colors, picked at random each time. Becca's wrong choice is always a very different color.
- Whatever comes next pulses (suitcase, dresser, pile, bundle, zipper), so it's always clear what to do.
- Tapping an item works like dragging it.
- Then tap to close the lid and drag the zipper shut, and a "you did it" video plays. Replay or go home at the end.
- If the child is idle, the other kid points at what to do next (after 6 seconds for Becca, 8 for Jack-Jack).
- Art comes in from the Kids Packing Video project through tools/import_art.py; releases refuse art that isn't approved yet.
- The v0.1 shirt demo is gone.

## [0.1.0] - 2026-10-29

First playable build, made to prove the pipeline end to end.

- One-screen bedroom level: drag the shirt from the bed into the open suitcase.
- A drop anywhere over the suitcase snaps the shirt in with a chime, a burst of stars and a big green checkmark. A miss glides the shirt back to the bed.
- A round replay button resets the level, as many times as you like.
- Version stamp in the bottom-left corner.
- Placeholder art and sound in the Kids Packing Video palette.
- GitHub Actions builds the web version to GitHub Pages and a signed Android APK for Fire and Android tablets.
