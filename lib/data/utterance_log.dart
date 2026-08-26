import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/utterance.dart';

/// On-device record of what was said.
///
/// Privacy rules, which are product requirements and not preferences:
///   * Off by default. Nothing is recorded until someone explicitly enables it.
///   * Never leaves the device. There is no network code path here at all.
///   * Capped, so it cannot grow without bound on a 16GB tablet.
///   * One tap to erase, irreversibly.
///
/// Stored by tile id rather than by text, so a log is not a transcript of a
/// private conversation -- it is a usage histogram.
abstract class UtteranceLog {
  List<Utterance> get entries;
  Future<void> add(Utterance utterance);
  Future<void> clear();
}

class StoredUtteranceLog implements UtteranceLog {
  StoredUtteranceLog._(this._prefs, this._entries);

  static const String _key = 'tesservox.utterances.v1';
  static const int maxEntries = 2000;

  static Future<StoredUtteranceLog> open() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? <String>[];
    final List<Utterance> parsed = <Utterance>[];
    for (final String line in raw) {
      try {
        parsed.add(
          Utterance.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } on Object {
        // Drop one bad line rather than losing a term's worth of history.
        continue;
      }
    }
    return StoredUtteranceLog._(prefs, parsed);
  }

  final SharedPreferences _prefs;
  final List<Utterance> _entries;

  @override
  List<Utterance> get entries => List<Utterance>.unmodifiable(_entries);

  @override
  Future<void> add(Utterance utterance) async {
    _entries.add(utterance);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    await _prefs.setStringList(
      _key,
      _entries
          .map((Utterance u) => jsonEncode(u.toJson()))
          .toList(growable: false),
    );
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    await _prefs.remove(_key);
  }
}

/// Used by tests and by the web demo.
class MemoryUtteranceLog implements UtteranceLog {
  final List<Utterance> _entries = <Utterance>[];

  @override
  List<Utterance> get entries => List<Utterance>.unmodifiable(_entries);

  @override
  Future<void> add(Utterance utterance) async => _entries.add(utterance);

  @override
  Future<void> clear() async => _entries.clear();
}
