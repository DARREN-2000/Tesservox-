import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/board.dart';

/// A pack as listed in the manifest, without loading its tiles.
class PackSummary {
  const PackSummary({
    required this.locale,
    required this.name,
    required this.voice,
    required this.tileCount,
    required this.sha256,
  });

  factory PackSummary.fromJson(Map<String, dynamic> json) => PackSummary(
        locale: json['locale'] as String,
        name: json['name'] as String,
        voice: json['voice'] as String,
        tileCount: json['tileCount'] as int,
        sha256: json['sha256'] as String,
      );

  final String locale;
  final String name;
  final String voice;
  final int tileCount;

  /// Written by `tool/build_packs.dart`. CI recompiles the YAML sources and
  /// fails if these hashes drift, which is how a hand-edited asset gets caught.
  final String sha256;
}

/// Reads compiled vocabulary packs out of the asset bundle.
///
/// Packs are authored as YAML in `packs/` and compiled to JSON by
/// `tool/build_packs.dart`. The app never parses YAML at runtime: startup on a
/// slow tablet is a real accessibility concern, and JSON decoding is ~10x
/// cheaper.
class PackLoader {
  const PackLoader({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  static const String manifestPath = 'assets/packs/manifest.json';

  Future<List<PackSummary>> available() async {
    final String raw = await _assets.loadString(manifestPath);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return (json['packs'] as List<dynamic>)
        .map((dynamic p) => PackSummary.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Loads a pack, falling back to English rather than throwing. A missing
  /// pack must degrade to "some voice" and not to "no voice".
  Future<VocabularyPack> load(String locale) async {
    try {
      return await _loadExact(locale);
    } on Object {
      if (locale == fallbackLocale) rethrow;
      return _loadExact(fallbackLocale);
    }
  }

  static const String fallbackLocale = 'en';

  Future<VocabularyPack> _loadExact(String locale) async {
    final String raw = await _assets.loadString('assets/packs/$locale.json');
    return VocabularyPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
