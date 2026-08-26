# Adding or fixing a language

This is the most useful thing you can do for this project, and it needs no
Dart and no Flutter.

## How packs are built

```
packs/core_words.yaml        ids + word class + glyph + grid   (authored ONCE)
packs/locales/<locale>.yaml  labels for those ids              (one per language)
            |
            |  dart run tool/build_packs.dart
            v
assets/packs/<locale>.json   compiled, hashed, committed
assets/packs/manifest.json
```

Locale files contain **only labels**. Ids, layout, colours and glyphs are
shared. That is deliberate: it makes "every language has the same core
vocabulary, in the same place" something the compiler enforces, instead of
something a README promises.

## Add a language

1. Copy `packs/locales/en.yaml` to `packs/locales/<locale>.yaml`.
2. Set `locale` (a BCP 47 tag), `name`, and `voice` (the platform voice tag,
   e.g. `sw-KE`).
3. Translate all 30 labels. Do not add, remove, rename or reorder ids.
4. Run:

   ```bash
   dart run tool/build_packs.dart
   flutter test
   ```

5. Commit both your YAML **and** the regenerated `assets/packs/`. CI runs
   `--check` and will fail if they disagree.

Miss a label and the build tells you exactly which one:

```
Pack error
----------
packs/locales/sw.yaml is missing 2 label(s): finished, toilet
Every locale must cover the whole core vocabulary. A blank tile is a word
this person cannot say.
```

## When the spoken form differs from the label

The tile shows `label`; the voice says `speak`. Add an optional `speak:` map
for the cases where they differ — a label shortened to fit a tile, or an
inflection the synthesiser needs:

```yaml
labels:
  thanks: danke
speak:
  thanks: danke schön
```

## Translation is the easy part. These are the real decisions

Please do not run the label list through a translation API. The things that
make an AAC board usable are exactly the things a translation API gets wrong:

- **Register.** Tamil and German both force a choice: நீ / நீங்கள், du / Sie. A
  child's board and an adult stroke patient's board are not the same board.
- **Verb form.** Imperative or infinitive? `சாப்பிடு` or `சாப்பிட`? Whichever
  combines most naturally with the rest of the board wins, not whichever is
  most correct in isolation.
- **Spoken vs written register**, which diverge sharply in Tamil. The board
  should sound like the person's family, not like a newspaper.
- **Regional variants.** Chennai, Madurai and Sri Lankan Tamil are not
  interchangeable here. Say which one you used in the PR.
- **Length.** A label has to be legible at a glance on a 96 px tile.

If you are unsure, open a PR anyway and say so in the description. A seed
translation with an honest note is far more useful than nothing, and that is
exactly what the current Tamil and German packs are.

## Changing the core 30

Harder, and welcome, but it affects every language and every user's motor
memory. Open an issue first. Two rules:

- **Never reorder or rename an existing id.** Ids are how sync and progress
  reports identify a tile, and position is what the user's hand learned.
- Appending is safe. Inserting is not.

The list follows core-vocabulary practice: high-frequency words that *combine*,
rather than a long tail of nouns. `more` is worth ten nouns. If you think a
word is missing, say which one it should replace.
