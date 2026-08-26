import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access_settings.dart';
import '../data/pack_loader.dart';
import '../data/settings_store.dart';
import '../data/utterance_log.dart';
import '../domain/board.dart';
import '../speech/speaker.dart';

/// Overridden in `main()` (and in tests) with a real or fake store.
final Provider<SettingsStore> settingsStoreProvider = Provider<SettingsStore>(
  (Ref ref) => throw UnimplementedError(
    'settingsStoreProvider must be overridden in ProviderScope',
  ),
);

final Provider<UtteranceLog> utteranceLogProvider = Provider<UtteranceLog>(
  (Ref ref) => throw UnimplementedError(
    'utteranceLogProvider must be overridden in ProviderScope',
  ),
);

final Provider<Speaker> speakerProvider =
    Provider<Speaker>((Ref ref) => PlatformSpeaker());

final Provider<PackLoader> packLoaderProvider =
    Provider<PackLoader>((Ref ref) => const PackLoader());

/// Access settings, persisted on every change.
class SettingsController extends Notifier<AccessSettings> {
  @override
  AccessSettings build() => ref.read(settingsStoreProvider).read();

  void save(AccessSettings next) {
    state = next;
    // Best effort: a failed disk write must never block speech.
    ref.read(settingsStoreProvider).write(next).ignore();
  }

  void setInputMethod(InputMethod method) =>
      save(state.copyWith(inputMethod: method));

  void setLocale(String locale) => save(state.copyWith(locale: locale));

  void setLogging({required bool enabled}) =>
      save(state.copyWith(logUtterances: enabled));
}

final NotifierProvider<SettingsController, AccessSettings> settingsProvider =
    NotifierProvider<SettingsController, AccessSettings>(
  SettingsController.new,
);

/// The active vocabulary pack. Reloads when the locale changes.
final FutureProvider<VocabularyPack> packProvider =
    FutureProvider<VocabularyPack>((Ref ref) {
  final String locale = ref.watch(settingsProvider).locale;
  return ref.watch(packLoaderProvider).load(locale);
});

final FutureProvider<List<PackSummary>> availablePacksProvider =
    FutureProvider<List<PackSummary>>(
  (Ref ref) => ref.watch(packLoaderProvider).available(),
);

/// The sentence being built, as tiles rather than as a string, so backspace,
/// re-speak and logging all operate on the same identities.
class MessageController extends Notifier<List<Tile>> {
  @override
  List<Tile> build() => const <Tile>[];

  void append(Tile tile) => state = <Tile>[...state, tile];

  void backspace() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
  }

  void clear() => state = const <Tile>[];
}

final NotifierProvider<MessageController, List<Tile>> messageProvider =
    NotifierProvider<MessageController, List<Tile>>(MessageController.new);
