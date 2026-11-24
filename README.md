# LettersPractice audio

The recorded audio for [LettersPractice](https://github.com/patched-network/letterspractice):
every word the app speaks, plus isolated phonemes. One speaker so far.

| Path | What | Used as |
|---|---|---|
| `words/<word>.mp3` | whole words | `/audio/words/<word>.mp3` |
| `phonemes/<name>.mp3` | isolated sounds, by teaching name (`cons_b`, …) | `/audio/phonemes/…` |
| `arpa/<ARPAbet>.mp3` | isolated sounds, by ARPAbet symbol (`SH`, `AE`, …) | `/audio/arpa/…` |

## Using it

The app's `scripts/setup-audio.sh` (run before `yarn dev`) clones the tag
pinned in its `audio.json` into `public/audio/`. To update the app to a new
version here: tag it, then bump `ref` and `commit` in the app's `audio.json`.

Versions are git tags (`v1`, `v2`, …). Adding words or re-recording is an
ordinary commit; tag when the app should pick it up. A second voice would go
under its own top-level directory (e.g. `voices/<name>/words/…`), with app
support to choose between them.

## Recording

How these files are made, and the tools for it (level check, splitting a
session into words, loudness normalization, a QA player), are in
[`RECORDING.md`](RECORDING.md). Using the audio needs none of it.

## License

Recordings © 2025–2026 Colin Kennedy, licensed under
[Creative Commons Attribution-NonCommercial 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
(full text: `LICENSE`). You may use, share and adapt them for non-commercial
purposes, with attribution. For commercial use, ask.

This license covers the audio only. The recording tools (`tools/`) are MIT
(`tools/LICENSE`); the app's code has its own license.
