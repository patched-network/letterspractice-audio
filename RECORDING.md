# Recording

How the audio here is made: record a session, check its levels, clean it,
split it into one file per word, normalize, listen, then copy into `words/`,
`arpa/` or `phonemes/`.

You need ffmpeg-capable Node (`npm install` here pulls `tsx` and a static
`ffmpeg`), Audacity, and a word list.

## Layout

```
lists/                  phoneme reading lists (arpabet.txt, -annotated with cue words), redos
tools/                  validate-recording, split-words, normalize-local, install-normalized.sh
tools/test-player/      browser player for QA
sessions/<name>/        one recording session (gitignored), by stage:
  01-raw/               raw recordings from Audacity (.aup3 + exported .wav)
  02-denoised/          after the cleanup pass (highpass and/or declick), .wav
                        (the name is historical: most sessions skip noise reduction; see §2)
  03-split/             one .wav per word, from split-words
  04-normalized/        final .mp3s, loudness-normalized with fades
```

Older sessions sit at the top level as `<MM-DD>-session/` (also gitignored).

## What to record

- **Words:** the app derives its list from its curriculum. In the app repo,
  `content/phoneticAnalytics` → `yarn gen:priorities` writes
  `outputs-v2/words-to-record.txt` (one word per line, in priority order); see
  that repo's `docs/word-recording-prioritization.md`. Record words not already
  in `words/`.
- **Phonemes:** `lists/arpabet.txt` (one ARPAbet symbol per line), or
  `lists/arpabet-annotated.txt`, which adds cue words to read from
  (`AE    cat, bat`). The split step names files by the first token on each line,
  so either list produces `AE.wav` etc.

For a long list, record in batches of ~50:

```bash
mkdir -p sessions/batches
split -l 50 -d --additional-suffix=.txt <path-to>/words-to-record.txt sessions/batches/batch-
```

## Workflow

Commands run from this repo's root. `S=sessions/<name>` below.

### 1. Record in Audacity

- Start with 5–10 s of room tone.
- Read the list with ~0.5 s pauses between words.
- Don't re-say flubs: note them for a redo batch.
- Save the project to `$S/01-raw/` and export a `.wav`.

### 1b. Validate levels

```bash
npm run validate -- $S/01-raw/session.wav
```

Checks peak level (-12 to -3 dBFS), dynamic range (>30 dB) and clipping. If it
fails, adjust mic gain and re-record before going further.

### 2. Clean up (highpass, not noise reduction)

**Don't apply Audacity's Noise Reduction by default.** Spectral-subtraction NR
leaves musical-noise artifacts on sustained harmonic content, most audibly on
vowels (a "scratchy" or "watery" texture on the formants). If the noise floor is
already low, NR does net harm.

Decide with the noise-floor probe below:

**If the speech band is clean** (per-band RMS in 500 Hz – 4 kHz at ≤ -80 dB
during room tone), skip NR and apply only a highpass for sub-audible rumble:

```bash
ffmpeg -i $S/01-raw/session.wav -af "highpass=f=80:poles=2" -c:a pcm_s16le \
  $S/02-denoised/session.wav
```

A linear filter: phase-coherent in the passband, no artifacts possible. It also
typically reclaims ~1 dB of headroom by removing rumble that piggybacks on
speech transients.

**If the room is noisier** (speech-band RMS above ~-70 dB), apply NR gently:
6 dB reduction (not 12+), sensitivity 3.0–4.0 (not 6), one pass. A/B against
the raw on a sustained vowel before committing.

Either way, export the result as `.wav` to `02-denoised/`.

#### Noise-floor probe

Per-band measurement of the first 5 s of room tone:

```bash
WAV=$S/01-raw/session.wav
for band in "20:80" "80:200" "200:500" "500:1000" "1000:2000" "2000:4000" "4000:8000"; do
  lo=${band%:*}; hi=${band#*:}
  rms=$(ffmpeg -i "$WAV" -t 5 -af "highpass=f=$lo,lowpass=f=$hi,astats=metadata=1:measure_overall=all:measure_perchannel=none" -f null - 2>&1 | grep "RMS level dB" | awk '{print $NF}' | head -1)
  printf "  %5s-%5s Hz: %s dB\n" "$lo" "$hi" "$rms"
done
```

What "good" looks like (the 05-15 session, blanket-fort setup):
- 20–80 Hz: -62 dB (rumble: the highpass handles it)
- 80–200 Hz: -70 dB (transition)
- 200 Hz – 8 kHz: -80 to -86 dB (clean: nothing for NR to remove)

### 2b. Declick (if needed)

Before splitting, look for sub-50 ms transients (mouth clicks, lip smacks,
chair or mic bumps in the pauses). They register as spurious speech segments and
break the count match in step 3.

Probe with silencedetect at the planned split threshold; if the segment count
exceeds the word list, dump the segment durations: anything under ~100 ms is an
artifact, not a take. Find it in Audacity and silence it (select → Generate >
Silence). Export to a new `.wav` (e.g. `session-declicked.wav`) before
splitting.

### 3. Split into words

```bash
npm run split -- $S/02-denoised/session.wav <word-list> \
  -o $S/03-split --noise -25dB --min-silence 0.5
```

- `--noise -25dB`: silence threshold. **Looser is better** here. Stricter
  thresholds (e.g. -45 dB) fragment one pause into several whenever a breath or
  mouth noise peeks above the floor, which inflates the segment count.
- `--min-silence 0.5`: minimum gap between words. Raise it if takes run
  together; lower it if your pauses are short.
- The script's defaults are `-30dB / 0.3s`.

If the segment count doesn't match the list, the script prints every detected
segment with timestamps: diff against the list to find the merged take or the
counted artifact.

### 4. Inspect the splits

Spot-check a few in Audacity for boundaries. For words ending in nasals (NG, M,
N), check the trailing nasal isn't cut mid-decay. Numerically, on the last 100 ms:

```bash
ffmpeg -sseof -0.1 -i $S/03-split/sing.wav \
  -af "astats=metadata=1:measure_overall=all:measure_perchannel=none" -f null - 2>&1 \
  | grep "RMS level"
```

A clean tail reaches the noise floor (-50 dB or lower); a truncated nasal shows
-25 to -35 dB. The 200 ms padding in `split-words.ts` plus a -25 dB threshold
usually covers a full NG decay; if not, raise `SEGMENT_PADDING` in the script or
lower the threshold.

### 5. Normalize, fade, encode to mp3

```bash
npm run normalize -- $S/03-split -o $S/04-normalized
```

Writes `<word>.normalized.mp3` per `.wav`.

### 6. QA in the browser

Open `tools/test-player/index.html`, drop in files from `04-normalized/`, and
check onsets and offsets sound clean.

### 7. Install and release

```bash
tools/install-normalized.sh $S/04-normalized words    # or arpa / phonemes
```

Copies each file into place without the `.normalized` suffix and says which
were added and which replaced. Then commit, and when the app should pick the
changes up, tag (`v2`, …) and bump `ref` + `commit` in the app's `audio.json`
(see `README.md`). Pushing audio to a running deployment is that deployment's
business, not this repo's.
