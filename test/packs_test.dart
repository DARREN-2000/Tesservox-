import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaani/domain/board.dart';

/// These tests are the reason a missing translation can never reach a user.
///
/// They run against the committed assets, which `tool/build_packs.dart`
/// compiles from `packs/*.yaml`. Together with `build_packs --check` in CI they
/// make "every locale has the whole core vocabulary, in the same order" a
/// property of the build rather than a promise in a README.
void main() {
  const String dir = 'assets/packs';

  late Map<String, dynamic> manifest;
  late Map<String, VocabularyPack> packs;
  late Map<String, String> rawJson;

  setUpAll(() {
    final File manifestFile = File('$dir/manifest.json');
    expect(
      manifestFile.existsSync(),
      isTrue,
      reason: 'Missing compiled packs. Run: dart run tool/build_packs.dart',
    );

    manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    packs = <String, VocabularyPack>{};
    rawJson = <String, String>{};

    for (final Object? entry in manifest['packs'] as List<dynamic>) {
      final Map<String, dynamic> summary = entry! as Map<String, dynamic>;
      final String locale = summary['locale'] as String;
      final String raw = File('$dir/$locale.json').readAsStringSync();
      rawJson[locale] = raw;
      packs[locale] = VocabularyPack.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
  });

  test('English, Tamil and German all ship', () {
    expect(packs.keys, containsAll(<String>['en', 'ta', 'de']));
  });

  test('manifest hashes match the files on disk', () {
    for (final Object? entry in manifest['packs'] as List<dynamic>) {
      final Map<String, dynamic> summary = entry! as Map<String, dynamic>;
      final String locale = summary['locale'] as String;
      final String actual =
          sha256.convert(utf8.encode(rawJson[locale]!)).toString();
      expect(
        actual,
        summary['sha256'],
        reason: '$locale.json was hand-edited. Recompile it.',
      );
      expect(summary['tileCount'], packs[locale]!.tiles.length);
    }
  });

  test('every locale ships exactly the same set of tile ids', () {
    final Set<String> reference =
        packs['en']!.tiles.map((Tile t) => t.id).toSet();

    for (final MapEntry<String, VocabularyPack> entry in packs.entries) {
      expect(
        entry.value.tiles.map((Tile t) => t.id).toSet(),
        reference,
        reason:
            '${entry.key} does not cover the same vocabulary as en. A blank '
            'tile is a word this person cannot say.',
      );
    }
  });

  test('tile order is identical across locales', () {
    // Motor planning: competent AAC use means reaching for "want" because your
    // hand knows where "want" is. If switching language moved the words, that
    // would be the same as deleting the board.
    final List<String> reference =
        packs['en']!.tiles.map((Tile t) => t.id).toList();

    for (final MapEntry<String, VocabularyPack> entry in packs.entries) {
      expect(
        entry.value.tiles.map((Tile t) => t.id).toList(),
        orderedEquals(reference),
        reason: '${entry.key} reorders the board',
      );
    }
  });

  test('word classes are identical across locales', () {
    // The Fitzgerald colour of a word is part of what the user learned. It
    // cannot change with the interface language.
    final List<WordClass> reference =
        packs['en']!.tiles.map((Tile t) => t.wordClass).toList();

    for (final MapEntry<String, VocabularyPack> entry in packs.entries) {
      expect(
        entry.value.tiles.map((Tile t) => t.wordClass).toList(),
        orderedEquals(reference),
        reason: '${entry.key} recolours the board',
      );
    }
  });

  test('no duplicate tile ids inside a pack', () {
    for (final MapEntry<String, VocabularyPack> entry in packs.entries) {
      final List<String> ids = entry.value.tiles.map((Tile t) => t.id).toList();
      expect(
        ids.toSet(),
        hasLength(ids.length),
        reason: '${entry.key} has duplicate ids; sync would be ambiguous',
      );
    }
  });

  test('the whole board fits its grid without scrolling', () {
    for (final MapEntry<String, VocabularyPack> entry in packs.entries) {
      expect(
        entry.value.tiles.length,
        lessThanOrEqualTo(entry.value.cellCount),
        reason:
            '${entry.key} has more tiles than cells. A scanning user cannot '
            'scroll, so a scrolled-off tile is an unsayable word.',
      );
      expect(entry.value.rows, greaterThan(0));
      expect(entry.value.cols, greaterThan(0));
    }
  });

  test('no tile is missing a label, a spoken form or a glyph', () {
    for (final MapEntry<String, VocabularyPack> entry in packs.entries) {
      for (final Tile tile in entry.value.tiles) {
        final String where = '${entry.key}/${tile.id}';
        expect(tile.label.trim(), isNotEmpty, reason: where);
        expect(tile.spoken.trim(), isNotEmpty, reason: where);
        expect(tile.glyph.trim(), isNotEmpty, reason: where);
      }
    }
  });

  test('every declared word class is one the app can colour', () {
    final Set<String> known =
        WordClass.values.map((WordClass c) => c.name).toSet();

    for (final MapEntry<String, String> entry in rawJson.entries) {
      final Map<String, dynamic> pack =
          jsonDecode(entry.value) as Map<String, dynamic>;
      for (final Object? raw in pack['tiles'] as List<dynamic>) {
        final Map<String, dynamic> tile = raw! as Map<String, dynamic>;
        expect(
          known,
          contains(tile['class']),
          reason:
              '${entry.key}/${tile['id']} has class "${tile['class']}", which '
              'would silently fall back to a noun colour',
        );
      }
    }
  });

  test('each pack declares a platform voice tag', () {
    for (final MapEntry<String, VocabularyPack> entry in packs.entries) {
      expect(
        entry.value.voice,
        matches(RegExp(r'^[a-z]{2}(-[A-Za-z0-9]+)*$')),
        reason: '${entry.key} has voice "${entry.value.voice}"',
      );
    }
  });
}
