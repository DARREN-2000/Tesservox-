import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access_settings.dart';
import '../access/scan_engine.dart';
import '../domain/board.dart';
import '../domain/utterance.dart';
import '../state/providers.dart';
import 'board_grid.dart';
import 'insights_page.dart';
import 'message_bar.dart';
import 'settings_page.dart';

/// The only screen that matters.
class SpeakPage extends ConsumerWidget {
  const SpeakPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VocabularyPack> pack = ref.watch(packProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: pack.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => _PackError(error: error),
          data: (VocabularyPack data) => _Board(pack: data),
        ),
      ),
    );
  }
}

class _PackError extends StatelessWidget {
  const _PackError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load the vocabulary pack.\nPlease check your settings or try restarting.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

/// Owns the [ScanEngine] for the lifetime of one pack geometry.
class _Board extends ConsumerStatefulWidget {
  const _Board({required this.pack});

  final VocabularyPack pack;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  late ScanEngine _engine;
  final FocusNode _switchFocus = FocusNode(debugLabel: 'switch-input');

  @override
  void initState() {
    super.initState();
    _engine = ScanEngine(
      settings: ref.read(settingsProvider),
      rows: widget.pack.rows,
      cols: widget.pack.cols,
      onSelect: _onScanSelect,
    );
  }

  @override
  void didUpdateWidget(_Board oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pack.rows != widget.pack.rows ||
        oldWidget.pack.cols != widget.pack.cols) {
      _engine.reconfigure(
        settings: ref.read(settingsProvider),
        rows: widget.pack.rows,
        cols: widget.pack.cols,
      );
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    _switchFocus.dispose();
    super.dispose();
  }

  void _onScanSelect(int index) {
    final Tile? tile = widget.pack.tileAt(index);
    if (tile != null) _addTile(tile);
  }

  void _addTile(Tile tile) {
    ref.read(messageProvider.notifier).append(tile);
    final AccessSettings settings = ref.read(settingsProvider);
    if (settings.speakEachWord) {
      _speak(tile.spoken, settings);
    }
  }

  void _speak(String text, AccessSettings settings) {
    ref
        .read(speakerProvider)
        .speak(
          text,
          voiceLocale: widget.pack.voice,
          rate: settings.speechRate,
          pitch: settings.pitch,
        )
        .ignore();
  }

  Future<void> _sayMessage() async {
    final List<Tile> tiles = ref.read(messageProvider);
    if (tiles.isEmpty) return;

    final AccessSettings settings = ref.read(settingsProvider);
    _speak(tiles.map((Tile t) => t.spoken).join(' '), settings);

    if (settings.logUtterances) {
      await ref.read(utteranceLogProvider).add(
            Utterance(
              tileIds: tiles.map((Tile t) => t.id).toList(growable: false),
              spokenAt: DateTime.now(),
              locale: widget.pack.locale,
            ),
          );
    }
    ref.read(messageProvider.notifier).clear();
  }

  /// Switch interfaces present themselves as keyboards, so keyboard keys are
  /// the real switch API -- and they make scanning testable on desktop and in
  /// CI without any hardware.
  ///
  ///   Space / Volume Down -> next
  ///   Enter / Volume Up   -> select
  ///   Escape              -> back out to row level
  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.audioVolumeDown) {
      _engine.pressNext();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.audioVolumeUp) {
      _engine.pressSelect();
    } else if (key == LogicalKeyboardKey.escape) {
      _engine.escape();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AccessSettings settings = ref.watch(settingsProvider);
    _engine.reconfigure(
      settings: settings,
      rows: widget.pack.rows,
      cols: widget.pack.cols,
    );

    final List<Tile> message = ref.watch(messageProvider);

    return KeyboardListener(
      focusNode: _switchFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            MessageBar(
              tiles: message,
              onSpeak: () => _sayMessage().ignore(),
              onBackspace: ref.read(messageProvider.notifier).backspace,
              onClear: ref.read(messageProvider.notifier).clear,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: _engine,
                builder: (BuildContext context, Widget? _) => BoardGrid(
                  pack: widget.pack,
                  highlighted: _engine.highlighted,
                  onTileTap: _addTile,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _Toolbar(pack: widget.pack),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.pack});

  final VocabularyPack pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AccessSettings settings = ref.watch(settingsProvider);

    return Row(
      children: <Widget>[
        Text(
          '${pack.name}  ·  ${settings.inputMethod.name}',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Insights',
          icon: const Icon(Icons.insights_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const InsightsPage(),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Access settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const SettingsPage(),
            ),
          ),
        ),
      ],
    );
  }
}
