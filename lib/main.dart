import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/settings_store.dart';
import 'data/utterance_log.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/12345'; // Stub DSN
    },
    appRunner: () async {
      // Load persisted state before the first frame. Access settings decide how the
      // very first screen behaves, so showing defaults and then swapping them would
      // move the highlight under a scanning user.
      SettingsStore settings;
      try {
        settings = await SettingsStore.open();
      } catch (e, st) {
        debugPrint('Failed to open SettingsStore: $e\n$st');
        settings = EphemeralSettingsStore();
      }

      UtteranceLog log;
      try {
        log = await StoredUtteranceLog.open();
      } catch (e, st) {
        debugPrint('Failed to open StoredUtteranceLog: $e\n$st');
        log = MemoryUtteranceLog();
      }

      runApp(
        ProviderScope(
          overrides: <Override>[
            settingsStoreProvider.overrideWithValue(settings),
            utteranceLogProvider.overrideWithValue(log),
          ],
          child: const TesservoxApp(),
        ),
      );
    },
  );
}
