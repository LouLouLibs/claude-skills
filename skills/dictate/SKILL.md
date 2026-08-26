---
name: dictate
description: Use when the user wants to transcribe a WAV or audio recording to Markdown with the dictate CLI, re-transcribe a recording with a different vocabulary, record a dictation from the terminal, or edit the dictation vocabulary file. Triggers on "transcribe this recording", "dictate", "voice memo to text", "vocab.txt", "Dictate.app", or a misspelled name in a transcript.
---

# dictate — local dictation with WhisperKit

[dictate](https://github.com/LouLouLibs/dictate) records from the microphone (or takes an
existing WAV) and transcribes it locally on the Neural Engine with WhisperKit (Whisper
large-v3 turbo), seeded with a vocabulary file so names and jargon come out spelled right.
Output is Markdown (YAML front matter + prose paragraphs) written to `NAME.txt` next to
the audio. macOS on Apple silicon only; nothing leaves the machine.

## Quick reference

```bash
dictate --from recording.wav                 # -> recording.txt next to the WAV
dictate --from recording.wav notes-v2        # choose the output name
dictate --from recording.wav --vocab v.txt   # a different vocabulary file
dictate --from recording.wav --html          # also render NAME.html (render-doc.sh)
dictate --from recording.wav --paragraph-gap 1.0   # new paragraph after 1 s of silence (default 1.5, 0 = never)
dictate --from recording.wav --model openai_whisper-large-v3-v20240930   # full model, ~4x slower
dictate section2                             # record interactively -> section2.{wav,txt}
dictate --no-transcribe                      # record only -> YYYYMMDD-HHMM-memo.wav
dictate --help
```

`dictate` refuses to overwrite an existing `.wav` or `.txt`; pick a new NAME or remove the
old file. NAME may include a directory (`out/section2`).

## Transcribing an existing recording (the usual case from Claude)

1. Check the vocabulary first: `cat ~/.config/dictate/vocab.txt`. If the user has named
   terms that must be spelled a certain way, add them at the top (see below) before running.
2. Run `dictate --from FILE.wav [NAME]`. It prints `Vocabulary: N terms`, a progress
   line, then `Wrote NAME.txt (P paragraphs, vocabulary prompt T tokens) in M:SS`.
3. Read `NAME.txt`. The body after the front matter is the transcript; hand it to the
   user or continue editing it. Punctuation and paragraph breaks come from the model.

WAV is the tested input (16 kHz mono PCM is native, anything AVFoundation reads is
converted). For other formats, convert first:
`ffmpeg -i in.m4a -ar 16000 -ac 1 -c:a pcm_s16le out.wav`.

Timing: about 5 s for a 40 s clip once the model is loaded. The **first** transcription
by a freshly built or downloaded `dictate` binary spends ~1.5 min compiling the model for
the Neural Engine (the message says so); the very first run ever also downloads the 1.6 GB
model to `~/.local/share/dictate/`. Use a long command timeout the first time.

## Recording from a terminal

Interactive: `dictate NAME`, then `space` pauses/resumes, `q` or `Ctrl-C` stops and
transcribes. Pauses leave no gap in the audio but start a new paragraph.

Claude cannot press keys in the user's terminal. For a timed recording from a script, pipe
the keys: `(sleep 90; printf q) | dictate NAME` records 90 s then transcribes. The
microphone permission belongs to the terminal app (System Settings > Privacy & Security >
Microphone); a flat level meter with a "no input signal" warning means it is missing.

## The vocabulary file

`~/.config/dictate/vocab.txt` (or `--vocab FILE`): one term or phrase per line,
**most important first**; blank lines and `#` comments are ignored.

- Whisper attends most to the top of the file (dictate places it closest to the
  transcript), and the prompt is capped at 223 tokens (~50 short terms); extra lines at
  the bottom are dropped with a warning naming them.
- A short list of 10-25 names and terms the model gets wrong works best; common words
  need no help. `dictate` prints the token count after each run.
- When the user reports a misspelling: add the correct spelling near the top of the file,
  then re-run `dictate --from FILE.wav NEWNAME` (the old `.txt` is not overwritten).

## Output format

```markdown
---
title: "section2"
date: 2026-08-24T15:42:10+02:00
audio: "section2.wav"
duration: "04:37"
model: "openai_whisper-large-v3-v20240930_turbo"
---

First paragraph ...

Second paragraph ...
```

`--html` renders it with `~/.claude/skills/rendering-spec-docs/render-doc.sh` (needs
pandoc) into `NAME.html` next to the transcript.

## Dictate.app

The same engine as a Mac app (`scripts/make-app.sh --install` in the repo, or
`Dictate.app.zip` on the releases page, then `xattr -dr com.apple.quarantine Dictate.app`).
It records with Record/Pause/Stop, transcribes into `~/Documents/Dictate` as
`YYYYMMDD-HHMM-memo.{wav,txt}`, accepts dropped WAVs, and has a menu-bar microphone.
Settings (⌘,) hold the save folder, model and vocabulary. Transcripts it writes can be
re-processed with the CLI exactly as above.

## Install

```bash
curl -L https://github.com/LouLouLibs/dictate/releases/latest/download/dictate-darwin-arm64 \
  -o ~/.local/bin/dictate && chmod +x ~/.local/bin/dictate
mkdir -p ~/.config/dictate && curl -L \
  https://github.com/LouLouLibs/dictate/releases/latest/download/vocab.txt -o ~/.config/dictate/vocab.txt
```

or from source: `git clone https://github.com/LouLouLibs/dictate && cd dictate && swift build -c release`
(Command Line Tools are enough; WhisperKit is the only dependency).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `microphone access is denied` | Enable the terminal app under System Settings > Privacy & Security > Microphone |
| `NAME.wav already exists` | Choose another NAME or remove the file |
| `warning: the vocabulary prompt exceeds Whisper's 223-token limit` | Shorten `vocab.txt`; the dropped lines are listed |
| Names still wrong | Move them to the top of `vocab.txt`; keep the file short; re-run with `--from` |
| `model unavailable` | Network needed for the one-time download from Hugging Face; check the `--model` name |
| Ctrl-C during transcription | Aborts; the WAV is kept; `dictate --from NAME.wav NAME` later |
