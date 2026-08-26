import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaani/access/access_settings.dart';
import 'package:vaani/data/pack_loader.dart';
import 'package:vaani/data/settings_store.dart';
import 'package:vaani/data/utterance_log.dart';
import 'package:vaani/speech/speaker.dart';
import 'package:vaani/state/providers.dart';
import 'package:vaani/ui/speak_page.dart';

/// End-to-end tests for the only screen that really matters.
///
/// Scanning is driven with real key events. Switch interfaces present
/// themselves to the OS as keyboards, so keyboard keys are the actual switch
/// API -- which means switch access is testable in CI with no hardware, and is
/// therefore tested rather than hoped for.
void main() {
  late _MemoryAssetBundle bundle;

  setUpAll(() {
    // Feed the widget under test the real committed assets, so a broken pack
    // fails here too, not only in packs_test.
    bundle = _MemoryAssetBundle(<String, String>{
      for (final String path in <String>[
        'assets/packs/manifest.json',
        'assets/packs/en.json',
        'assets/packs/ta.json',
        'assets/packs/de.json',
      ])
        path: File(path).readAsStringSync(),
    });
  });

  Widget harness({
    required Speaker speaker,
    AccessSettings settings = const AccessSettings(),
    UtteranceLog? log,
  }) =>
      ProviderScope(
        overrides: <Override>[
          settingsStoreProvider.overrideWithValue(
            EphemeralSettingsStore(settings),
          ),
          utteranceLogProvider.overrideWithValue(log ?? MemoryUtteranceLog()),
          speakerProvider.overrideWithValue(speaker),
          packLoaderProvider.overrideWithValue(PackLoader(bundle: bundle)),
        ],
        child: const MaterialApp(home: SpeakPage()),
      );

  testWidgets('the English core board renders', (WidgetTester tester) async {
    await tester.pumpWidget(harness(speaker: RecordingSpeaker()));
    await tester.pumpAndSettle();

    expect(find.text('want'), findsOneWidget);
    expect(find.text('more'), findsOneWidget);
    expect(find.text('toilet'), findsOneWidget);
  });

  testWidgets('the Tamil pack renders Tamil labels in the same places', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        speaker: RecordingSpeaker(),
        settings: const AccessSettings(locale: 'ta'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('வேண்டும்'), findsOneWidget); // want
    expect(find.text('தண்ணீர்'), findsOneWidget); // water
    expect(find.text('want'), findsNothing);
  });

  testWidgets('tapping a tile speaks it and adds it to the message', (
    WidgetTester tester,
  ) async {
    final RecordingSpeaker speaker = RecordingSpeaker();
    await tester.pumpWidget(harness(speaker: speaker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('want'));
    await tester.pumpAndSettle();

    expect(speaker.spoken, <String>['want']);
    expect(find.byType(Chip), findsOneWidget);
  });

  testWidgets('Say speaks the whole sentence and clears the bar', (
    WidgetTester tester,
  ) async {
    final RecordingSpeaker speaker = RecordingSpeaker();
    await tester.pumpWidget(harness(speaker: speaker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('want'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Say'));
    await tester.pumpAndSettle();

    expect(speaker.spoken.last, 'want water');
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('backspace removes only the last word', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(speaker: RecordingSpeaker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('want'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('water'));
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsNWidgets(2));

    await tester.tap(find.byTooltip('Delete last word'));
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsOneWidget);
  });

  testWidgets('two-switch scanning: step to a row, drill in, select a word', (
    WidgetTester tester,
  ) async {
    final RecordingSpeaker speaker = RecordingSpeaker();
    await tester.pumpWidget(
      harness(
        speaker: speaker,
        settings: const AccessSettings(
          inputMethod: InputMethod.twoSwitch,
          // The tremor filter would otherwise eat synthetic key events, which
          // all arrive within the same millisecond.
          debounce: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Row 0 is people; row 1 is actions, whose first cell is "want".
    await tester.sendKeyEvent(LogicalKeyboardKey.space); // -> row 1
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // drill into row 1
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // select cell (1, 0)
    await tester.pumpAndSettle();

    expect(speaker.spoken, <String>['want']);
  });

  testWidgets('the tremor filter turns a double press into one intention', (
    WidgetTester tester,
  ) async {
    final RecordingSpeaker speaker = RecordingSpeaker();
    await tester.pumpWidget(
      harness(
        speaker: speaker,
        settings: const AccessSettings(
          inputMethod: InputMethod.twoSwitch,
          debounce: Duration(seconds: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Without a tremor filter these two presses would drill into row 0 and
    // then immediately say "I".
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(speaker.spoken, isEmpty);
  });

  testWidgets('touch users see no scan highlight at all', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(speaker: RecordingSpeaker()));
    await tester.pumpAndSettle();

    // No tile reports itself as selected, so TalkBack does not announce a
    // highlight that is not there.
    final Iterable<Semantics> selected = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((Semantics s) => s.properties.selected ?? false);
    expect(selected, isEmpty);
  });

  testWidgets('nothing is logged unless logging was turned on', (
    WidgetTester tester,
  ) async {
    final MemoryUtteranceLog log = MemoryUtteranceLog();
    await tester.pumpWidget(harness(speaker: RecordingSpeaker(), log: log));
    await tester.pumpAndSettle();

    await tester.tap(find.text('want'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Say'));
    await tester.pumpAndSettle();

    expect(log.entries, isEmpty, reason: 'logging is off by default');
  });

  testWidgets('with logging on, an utterance is recorded by tile id', (
    WidgetTester tester,
  ) async {
    final MemoryUtteranceLog log = MemoryUtteranceLog();
    await tester.pumpWidget(
      harness(
        speaker: RecordingSpeaker(),
        settings: const AccessSettings(logUtterances: true),
        log: log,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('want'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Say'));
    await tester.pumpAndSettle();

    expect(log.entries, hasLength(1));
    // Ids, not labels: a report has to survive translating or relabelling a
    // board, and it should not be a transcript of a private conversation.
    expect(log.entries.single.tileIds, <String>['want', 'water']);
    expect(log.entries.single.locale, 'en');
  });
}

/// Serves a fixed map of assets, so widget tests can read the real pack files
/// without a Flutter asset bundle being present.
class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final String? content = files[key];
    if (content == null) {
      throw FlutterError('No test asset registered for "$key"');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}
