import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../access/access_settings.dart';

/// Persists access settings.
///
/// A shared classroom tablet gets rebooted constantly. If a user's scan speed
/// and switch configuration do not survive that, the device is unusable for
/// them, so this is load-bearing rather than a nicety.
class SettingsStore {
  const SettingsStore(this._prefs);

  static const String _key = 'vaani.access.v1';

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  AccessSettings read() {
    final String? raw = _prefs.getString(_key);
    if (raw == null) return const AccessSettings();
    try {
      return AccessSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      // Corrupt settings must never brick someone's only way of speaking.
      // Defaults are always usable, so fall back silently.
      return const AccessSettings();
    }
  }

  Future<void> write(AccessSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));
}

/// In-memory store for tests and for the web demo, where there is nothing
/// worth persisting and no consent to persist it.
class EphemeralSettingsStore implements SettingsStore {
  EphemeralSettingsStore([this._value = const AccessSettings()]);

  AccessSettings _value;

  @override
  AccessSettings read() => _value;

  @override
  Future<void> write(AccessSettings settings) async => _value = settings;
}
