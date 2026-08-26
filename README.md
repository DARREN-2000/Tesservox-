<h1 align="center">Vaani — வாணி</h1>

<p align="center">
  <b>A free, offline, multilingual AAC app for people who cannot speak.</b><br>
  Flutter · Android, iOS, Linux, Web · no account, no cloud, no subscription
</p>

---

## Why this exists

AAC (Augmentative and Alternative Communication) is how non-speaking people
talk: a grid of words, tapped or scanned, spoken aloud by the device.

The good apps cost more than the tablet they run on.
[Proloquo2Go](https://www.assistiveware.com/products/proloquo2go) is
**$249.99**, iOS-only, and ships four languages. TouchChat is around $299.99.
For a family in Chennai, Nairobi or rural Bavaria, the price of *speech* is a
month of income and an iPad they do not own.

And if your language is not English, Spanish, French or Dutch, the app you can
afford does not speak it at all.

Vaani is the boring, unglamorous alternative:

| | Vaani |
|---|---|
| **Price** | €0, forever, MIT licensed |
| **Network** | never. No account, no telemetry, no cloud TTS |
| **Hardware** | any Android 6+ tablet, including a €60 one |
| **Languages** | English, **Tamil**, German — and adding one is a 30-line YAML file |
| **Access** | touch, dwell, **one-switch auto-scan**, **two-switch step-and-select** |
| **Data** | usage logging is **off by default**, on-device only, erasable in one tap |

Tamil has ~80 million speakers and effectively no free AAC vocabulary. That is
the kind of gap this project is aimed at.

---

## What is actually here

```
lib/
  domain/       pure Dart, zero Flutter imports — all the hard logic
    scanning.dart     switch-scanning as a deterministic state machine
    hlc.dart          hybrid logical clock for serverless peer sync
    ops.dart          last-writer-wins CRDT over an op log
    board.dart        tiles, packs, Fitzgerald word classes
    coverage.dart     the progress report a therapist currently does by hand
  access/       input methods, timing, tremor filtering
  data/         asset packs, settings, the local utterance log
  speech/       Speaker interface (platform TTS today, offline voice next)
  state/        Riverpod wiring
  ui/           the speak grid, message bar, access settings, insights
packs/          human-authored vocabulary YAML (the contribution surface)
tool/           the pack compiler + `--check` drift gate
test/           property tests, convergence tests, widget tests
```

---

## The five problems this project is really about

Anyone can build a grid of buttons that speak. These are the parts that decide
whether a real person can use it.

### 1. Switch scanning, as a state machine with no clock in it

A single-switch user cannot point. The app moves the highlight; they press once
when it lands on the word they want. If that logic is wrong they say the wrong
thing **and cannot tell you why**.

So `domain/scanning.dart` has no Flutter imports and no timers. It is a pure
function of presses, and it is tested over hundreds of pseudo-random press
sequences asserting that the cursor is *always* in range and that every real
selection returns to a predictable origin. The timer lives in
`access/scan_engine.dart`, separately, where it is the only thing that can be
flaky.

Row-column scanning is O(rows + cols) instead of O(rows × cols): on the 5×6
core board that is 11 presses worst case instead of 30. At a 1.2 s scan
interval, that is a 13-second word instead of a 36-second word — the difference
between having a conversation and not having one. There is a test for it.

### 2. Motor planning means a word may never move

Competent AAC use is motor learning. The user reaches for `want` because their
hand knows where `want` is. An adaptive, frecency-sorted, "smart" layout would
be a **regression**, not a feature.

So the board is a fixed grid; geometry comes from the pack, never from the
content; and `test/packs_test.dart` asserts that all three locales ship the
same tile ids, in the same order, with the same Fitzgerald colours. Switching
language cannot move a single word.

### 3. A vocabulary compiler, so a missing translation is a red build

N locales × M words, hand-maintained as JSON, drifts silently. One locale ends
up with 29 words and a blank tile that a child discovers mid-sentence.

Instead: `packs/core_words.yaml` holds ids, word classes, glyphs and layout
**once**. Locale files supply only labels. `tool/build_packs.dart` joins them,
validates them, and emits hashed JSON assets. CI runs it with `--check`, so a
stale or hand-edited asset fails the build.

```bash
dart run tool/build_packs.dart          # compile packs/ -> assets/packs/
dart run tool/build_packs.dart --check  # CI drift gate
```

### 4. Serverless sync between a parent's phone and a child's tablet

A therapist edits the board on their phone; the child's school tablet has never
seen the internet and thinks it is 1970. There is no server, because a server
means an account, and an account means a login screen between a person and
their voice.

`domain/hlc.dart` is a hybrid logical clock: monotonic per device even when the
wall clock jumps backwards, totally ordered so two devices can never both think
they won. `domain/ops.dart` folds an op log into last-writer-wins state, which
makes merging a set union plus a max — commutative, associative and
**idempotent**, so a re-scanned QR bundle can never fork a board.

`test/ops_convergence_test.dart` shuffles a generated two-device op log 200
ways and asserts every replica reaches an identical fingerprint, and that
replaying the whole log changes nothing.

> A full CRDT (RGA, Yjs, Automerge) buys ordered-list convergence. Vaani does
> not need it, because tiles live at fixed positions **on purpose**. LWW per
> field is the correct amount of machinery, and that trade-off is deliberate.

### 5. The progress report, computed on-device

Speech and language therapists want core-word coverage and mean utterance
length. Today they get it by watching video with a tally sheet.

`domain/coverage.dart` computes it from the local log: coverage %, longest
utterance, mean utterance length, and a least-used-first list of core words
the person has not reached this week — which is next week's therapy plan, and
exports as CSV.

Utterances are stored **by tile id, not by label**, so a report survives
translating a board and is not a transcript of a private conversation. Logging
is off until someone turns it on, never leaves the device, and erases in one
tap.

---

## Running it

```bash
flutter pub get
dart run tool/build_packs.dart   # compile the vocabulary assets
flutter test
flutter run                      # or: flutter run -d linux / -d chrome
```

Switch access works on desktop and web too, because switch interfaces present
themselves to the OS as keyboards:

| Key | Action |
|---|---|
| `Space` / volume-down | next |
| `Enter` / volume-up | select |
| `Escape` | back out to row level |

That is also why switch access is covered by widget tests instead of being
hoped for.

---

## Adding a language

One file. See [`packs/README.md`](packs/README.md).

```yaml
# packs/locales/sw.yaml
locale: sw
name: Kiswahili core 30
voice: sw-KE
labels:
  i: mimi
  you: wewe
  # ... 28 more
```

The compiler refuses to build if you miss one, and tells you which.

---

## Status — read this before trusting it

This is **pre-alpha and not clinically validated**. Specifically:

- The Tamil and German labels are seed translations that **need a native review
  pass** for register, politeness and inflection. Those calls belong to a
  speaker and a therapist, not to a translation API. See the notes at the top
  of each locale file.
- Offline TTS is not wired in yet. Today Vaani uses the platform voice, which
  means Tamil quality depends on what the device has installed — the exact
  problem this project intends to fix. Bundling a Piper voice via FFI is the
  next milestone; see the TODO in `speech/speaker.dart`.
- Peer-to-peer sync has a tested, converging core (HLC + LWW op log) but no
  transport yet.
- It has not been used by an actual AAC user. That is the only test that counts,
  and it has not happened.

## Wanted

- **Native speakers** of any language, especially Tamil, to review or add a pack
- **Speech and language therapists** to tell me the core-30 list is wrong
- **Switch users** to tell me the timing defaults are wrong

## Symbols and licensing

The shipped glyphs are placeholder emoji, deliberately. Real AAC symbol sets
are a licensing minefield — ARASAAC is CC BY-NC-SA (non-commercial only),
SymbolStix and PCS are proprietary. See
[`ASSETS-LICENSE.md`](ASSETS-LICENSE.md) before adding any symbol set.

## Licence

MIT. Speech should not have a paywall.
