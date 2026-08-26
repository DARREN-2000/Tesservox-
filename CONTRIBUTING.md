# Contributing

The goal is narrow: a non-speaking person can pick up a cheap tablet and say
something, in their own language, with no account, no network and no payment.
Contributions are judged against that.

## The most valuable things you can do

None of these require Dart.

1. **Review or add a language pack.** One 30-line YAML file. See
   [`packs/README.md`](packs/README.md). Tamil and German currently hold seed
   translations that need a native pass for register and inflection.
2. **Tell me the core 30 is wrong.** If you are a speech and language
   therapist, the word list is the highest-leverage thing in the repo and I am
   not qualified to have picked it. Open an issue.
3. **Tell me the timing defaults are wrong.** If you use a switch, the 1200 ms
   scan interval, 800 ms dwell and 300 ms debounce are guesses. Yours are data.
4. **Try it on an old tablet** and report what happened.

## Ground rules that are not negotiable

These are the constraints the whole design rests on. A PR that breaks one will
be declined even if the code is good.

- **No network calls.** No analytics, no crash reporting, no cloud TTS, no
  remote config, no fonts fetched at runtime. The app must work in airplane
  mode forever.
- **No accounts and no login screen.** Nothing may stand between a person and
  their voice.
- **A word may never move.** No adaptive, frecency-sorted or "smart" reordering
  of tiles. Competent AAC use is motor learning; moving a word is worse than
  removing it.
- **Usage logging stays off by default**, on-device, and erasable in one tap.
- **The whole board must be reachable without scrolling.** A scanning user
  cannot scroll, so a scrolled-off tile is an unsayable word.
- **No feature may require paying anyone.** Including us.

## Code

- `lib/domain/` is pure Dart with **zero Flutter imports**. All the logic that
  can be wrong in a way a user cannot see — scanning, clocks, merges, coverage
  — lives there and is unit tested. Keep it that way.
- Anything with a timer in it goes in `lib/access/`, so the flaky part is
  isolated.
- Adding an input method means adding a case to `InputMethod` and to the
  scan engine. `missing_enum_case_in_switch` is an **error**, so the compiler
  will find the places you forgot.

Before opening a PR:

```bash
flutter pub get
dart run tool/build_packs.dart --check
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

CI runs exactly that.

## Tests

- Scanning, HLC and CRDT behaviour are tested as **properties over generated
  input** (with fixed seeds), not as a handful of examples. The failure mode in
  the field is an interleaving nobody thought of.
- Switch access is tested with real key events, because switch interfaces
  present themselves as keyboards. If you touch the scan engine, the widget
  tests must still pass.
- New vocabulary needs no new tests — `test/packs_test.dart` already asserts
  every locale covers the same ids in the same order with the same colours.

## Accessibility bar

Every interactive element needs a `Semantics` label that reads sensibly in
TalkBack and VoiceOver. Touch targets are 48 dp minimum. Colour is never the
only signal — the Fitzgerald key is a learning aid layered on top of text and a
glyph, not a substitute for either.

## Reporting an accessibility bug

Say what the person was trying to do, what input method they use, and what the
device did. "The highlight skipped a row when I pressed twice quickly" is a
perfect bug report and points straight at the debounce logic.
