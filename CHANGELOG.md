# Changelog

All notable changes to this project are documented here.

## [0.2.0] - Unreleased

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
