import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

/// Compiles human-authored YAML vocabulary into the JSON the app ships.
///
/// Why a compiler at all: N locales x M words, hand-maintained as JSON, is a
/// guaranteed source of silent drift -- a missing translation, a duplicated id,
/// a locale that quietly has 29 words instead of 30. Here every one of those is
/// a build failure with a message aimed at the person who caused it.
///
/// One engine, N declarative config files, validated in CI. The same shape as a
/// data-pipeline mapping spec, for the same reason: the alternative is N
/// hand-maintained copies that diverge.
library;

/// An authoring mistake. The message is written for a translator or a
/// therapist, not for a compiler engineer.
class PackError implements Exception {
  PackError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Must stay in sync with `WordClass` in `lib/domain/board.dart`.
const Set<String> kWordClasses = <String>{
  'people',
  'action',
  'describer',
  'noun',
  'social',
  'question',
};

class CoreWord {
  const CoreWord({
    required this.id,
    required this.wordClass,
    required this.glyph,
  });

  final String id;
  final String wordClass;
  final String glyph;
}

class CoreSpec {
  const CoreSpec({
    required this.rows,
    required this.cols,
    required this.words,
  });

  final int rows;
  final int cols;
  final List<CoreWord> words;

  List<String> get ids =>
      words.map((CoreWord w) => w.id).toList(growable: false);
}

class CompiledPack {
  const CompiledPack({
    required this.locale,
    required this.name,
    required this.voice,
    required this.tileCount,
    required this.json,
    required this.sha256,
  });

  final String locale;
  final String name;
  final String voice;
  final int tileCount;
  final String json;
  final String sha256;
}

Map<String, dynamic> _asMap(Object? node, String what) {
  if (node is Map) {
    return node.map<String, dynamic>(
      (Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v),
    );
  }
  throw PackError('$what should be a mapping, found ${node.runtimeType}');
}

String? _str(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value == null) {
    return null;
  }
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

class PackCompiler {
  const PackCompiler({required this.packsDir});

  final Directory packsDir;

  static const JsonEncoder _json = JsonEncoder.withIndent('  ');

  File get coreFile => File('${packsDir.path}/core_words.yaml');

  Directory get localesDir => Directory('${packsDir.path}/locales');

  CoreSpec readCore() {
    if (!coreFile.existsSync()) {
      throw PackError('Missing ${coreFile.path}');
    }
    final Map<String, dynamic> doc = _asMap(
      loadYaml(coreFile.readAsStringSync()),
      coreFile.path,
    );
    final Map<String, dynamic> grid = _asMap(doc['grid'], 'grid');
    final int rows = (grid['rows'] as num?)?.toInt() ?? 0;
    final int cols = (grid['cols'] as num?)?.toInt() ?? 0;
    if (rows <= 0 || cols <= 0) {
      throw PackError('grid.rows and grid.cols must both be positive');
    }

    final Object? rawWords = doc['words'];
    if (rawWords is! List) {
      throw PackError('"words" should be a list of entries');
    }

    final List<CoreWord> words = <CoreWord>[];
    final Set<String> seen = <String>{};
    for (final Object? entry in rawWords) {
      final Map<String, dynamic> word = _asMap(entry, 'word entry');
      final String? id = _str(word, 'id');
      final String? wordClass = _str(word, 'class');
      final String? glyph = _str(word, 'glyph');

      if (id == null) {
        throw PackError('a word entry is missing its id');
      }
      if (!seen.add(id)) {
        throw PackError(
          'duplicate word id "$id". Ids are how sync and progress reports '
          'identify a tile, so they have to be unique.',
        );
      }
      if (wordClass == null || !kWordClasses.contains(wordClass)) {
        throw PackError(
          'word "$id" has class "$wordClass"; expected one of '
          '${kWordClasses.join(", ")}',
        );
      }
      if (glyph == null) {
        throw PackError('word "$id" has no glyph');
      }

      words.add(CoreWord(id: id, wordClass: wordClass, glyph: glyph));
    }

    if (words.isEmpty) {
      throw PackError('the core word list is empty');
    }
    if (words.length > rows * cols) {
      throw PackError(
        '${words.length} words will not fit a ${rows}x$cols grid. The whole '
        'board has to be reachable without scrolling: a scanning user cannot '
        'scroll, so a scrolled-off tile is an unsayable word.',
      );
    }

    return CoreSpec(rows: rows, cols: cols, words: words);
  }

  CompiledPack compileLocale(CoreSpec core, File file) {
    final Map<String, dynamic> doc = _asMap(
      loadYaml(file.readAsStringSync()),
      file.path,
    );

    final String? locale = _str(doc, 'locale');
    final String? name = _str(doc, 'name');
    final String? voice = _str(doc, 'voice');
    if (locale == null || name == null || voice == null) {
      throw PackError('${file.path}: locale, name and voice are all required');
    }

    final Map<String, dynamic> labels = _asMap(
      doc['labels'],
      '${file.path} "labels"',
    );
    final Map<String, dynamic> overrides = doc['speak'] == null
        ? <String, dynamic>{}
        : _asMap(doc['speak'], '${file.path} "speak"');

    final Set<String> expected = core.ids.toSet();
    final List<String> missing =
        expected.difference(labels.keys.toSet()).toList()..sort();
    final List<String> extra =
        labels.keys.toSet().difference(expected).toList()..sort();
    final List<String> stray =
        overrides.keys.toSet().difference(expected).toList()..sort();

    if (missing.isNotEmpty) {
      throw PackError(
        '${file.path} is missing ${missing.length} label(s): '
        '${missing.join(", ")}\n'
        'Every locale must cover the whole core vocabulary. A blank tile is a '
        'word this person cannot say.',
      );
    }
    if (extra.isNotEmpty) {
      throw PackError(
        '${file.path} has ${extra.length} label(s) with no matching core '
        'word: ${extra.join(", ")}',
      );
    }
    if (stray.isNotEmpty) {
      throw PackError(
        '${file.path} has speak overrides for unknown ids: '
        '${stray.join(", ")}',
      );
    }

    final List<Map<String, dynamic>> tiles = <Map<String, dynamic>>[];
    for (final CoreWord word in core.words) {
      final String? label = _str(labels, word.id);
      if (label == null) {
        throw PackError('${file.path}: the label for "${word.id}" is empty');
      }
      tiles.add(<String, dynamic>{
        'id': word.id,
        'label': label,
        // The spoken form defaults to the label. Override it when register or
        // inflection differ, or when the label was shortened to fit a tile.
        'speak': _str(overrides, word.id) ?? label,
        'glyph': word.glyph,
        'class': word.wordClass,
      });
    }

    // Tile ORDER is the grid layout, and it comes from core_words.yaml rather
    // than from the locale file. That is what makes "the same word is in the
    // same place in every language" a structural guarantee instead of a habit.
    final String json = '${_json.convert(<String, dynamic>{
      'locale': locale,
      'name': name,
      'voice': voice,
      'rows': core.rows,
      'cols': core.cols,
      'tiles': tiles,
    })}\n';

    return CompiledPack(
      locale: locale,
      name: name,
      voice: voice,
      tileCount: tiles.length,
      json: json,
      sha256: sha256.convert(utf8.encode(json)).toString(),
    );
  }

  List<CompiledPack> compileAll() {
    final CoreSpec core = readCore();
    if (!localesDir.existsSync()) {
      throw PackError('Missing ${localesDir.path}');
    }

    final List<File> files = localesDir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.yaml'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      throw PackError('No locale files found in ${localesDir.path}');
    }

    final List<CompiledPack> packs = files
        .map((File f) => compileLocale(core, f))
        .toList(growable: false);

    final Set<String> locales = <String>{};
    for (final CompiledPack pack in packs) {
      if (!locales.add(pack.locale)) {
        throw PackError(
          'two locale files both declare locale "${pack.locale}"',
        );
      }
    }

    return packs;
  }

  /// Deterministic on purpose: sorted by locale, and with no build timestamp.
  /// An artefact with a timestamp in it cannot be diffed or checked for drift.
  String manifestJson(List<CompiledPack> packs) {
    final List<CompiledPack> sorted = List<CompiledPack>.of(packs)
      ..sort((CompiledPack a, CompiledPack b) => a.locale.compareTo(b.locale));

    return '${_json.convert(<String, dynamic>{
      'version': 1,
      'packs': sorted
          .map(
            (CompiledPack pack) => <String, dynamic>{
              'locale': pack.locale,
              'name': pack.name,
              'voice': pack.voice,
              'tileCount': pack.tileCount,
              'sha256': pack.sha256,
            },
          )
          .toList(growable: false),
    })}\n';
  }
}
