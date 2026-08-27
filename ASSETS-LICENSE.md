# Symbols, voices and licensing

Read this before adding any symbol set or voice. AAC symbol licensing is a
minefield, and getting it wrong would make Tesservox undistributable — which would
defeat the entire point of the project.

## Why the shipped glyphs are emoji

The tiles currently show Unicode emoji. That is a deliberate placeholder, not
laziness. Emoji are:

- already on every device, so they add zero download size,
- unencumbered, so nothing blocks redistribution,
- and honest about being a placeholder.

They are **not** good AAC symbols. Real symbol sets are designed for
transparency and iconicity, tested with users, and internally consistent.
Emoji are none of those things. Replacing them is on the roadmap; the table
below is the decision that has to be made first.

## Symbol sets

| Set | Size | Licence | Usable here? |
|---|---|---|---|
| **Mulberry Symbols** | ~3,900 | CC BY-SA 4.0 | **Yes.** Commercial use fine, share-alike on the symbols. The current front-runner. |
| **OpenMoji** | ~4,000 | CC BY-SA 4.0 | **Yes**, and consistent, but not designed for AAC. |
| **ARASAAC** | 30,000+ | CC BY-NC-SA | **Careful.** Non-commercial only. Fine for a free app, but it permanently forecloses ever charging for anything, and "NC" is legally murky for app-store distribution. Requires crediting the author (Sergio Palao) and Gobierno de Aragón. |
| **SymbolStix** | 15,000+ | Proprietary | No. Licensed per-app, commercially. |
| **PCS (Picture Communication Symbols)** | 9,000+ | Proprietary (Tobii Dynavox) | No. |
| **Blissymbolics** | — | Licence required from BCI | No. |

**Current recommendation:** Mulberry Symbols, CC BY-SA 4.0, attributed in-app
and in this file. It keeps the project unambiguously redistributable.

If you add ARASAAC, it must be behind an optional download so the core app
stays free of an NC restriction, and the attribution must be visible in the
app, not just in a repo file.

## Voices

Today Tesservox calls the platform TTS via `flutter_tts`. That is a real limitation,
not a design choice: on a cheap Android tablet there may be **no Tamil voice
installed at all**, which is precisely the problem this app exists to solve.

| Option | Licence | Notes |
|---|---|---|
| Platform TTS (current) | — | Free, zero size, but availability and quality are out of our hands. |
| **Piper** | MIT (engine) | Fast, fully offline, runs on a Raspberry Pi. ~20–60 MB per voice. Voice models carry their **own** licences — check each one individually. |
| eSpeak NG | GPL v3 | Tiny and covers a huge number of languages, but robotic. GPL v3 would force the whole app to GPL. |
| Coqui TTS | MPL 2.0 | Good quality, too heavy for a €60 tablet. |
| Any cloud TTS | — | **Excluded by design.** It would require a network, an account, and sending everything a non-speaking person says to a server. |

**Planned:** bundle Piper via `dart:ffi`, downloading voices on demand and
recording each voice model's licence in this file. See the TODO in
`lib/speech/speaker.dart`.

## Tesservox's own content

- Code: MIT (see `LICENSE`).
- The vocabulary packs in `packs/` (word lists, labels, translations): MIT,
  same as the code, so any other AAC project can take them.

## Attribution block to keep updated

When a third-party asset ships in the app, it goes here **and** on an
in-app about screen:

```
Symbols: <set>, <licence>, <author/holder>, <url>
Voices:  <voice>, <licence>, <author/holder>, <url>
```

Currently: none. The glyphs are Unicode emoji rendered by the host platform's
own font, so nothing is redistributed.
