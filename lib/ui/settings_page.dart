import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access_settings.dart';
import '../data/pack_loader.dart';
import '../domain/scanning.dart';
import '../state/providers.dart';

/// Access settings.
///
/// This screen is used by a therapist or parent, not usually by the AAC user,
/// so it can be dense. Every control here changes how a person physically
/// reaches a word, which is why none of it is hidden behind "advanced".
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AccessSettings s = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);
    final AsyncValue<List<PackSummary>> packs =
        ref.watch(availablePacksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Access')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _Heading('How this person selects'),
          for (final InputMethod method in InputMethod.values)
            RadioListTile<InputMethod>(
              value: method,
              groupValue: s.inputMethod,
              title: Text(_inputMethodTitle(method)),
              subtitle: Text(_inputMethodBlurb(method)),
              onChanged: (InputMethod? v) {
                if (v != null) controller.setInputMethod(v);
              },
            ),

          if (s.isScanning) ...<Widget>[
            const _Heading('Scanning'),
            SwitchListTile(
              value: s.scanMode == ScanMode.rowColumn,
              title: const Text('Row-column scanning'),
              subtitle: const Text(
                'Scan rows first, then cells. Far fewer steps on a big grid.',
              ),
              onChanged: (bool v) => controller.save(
                s.copyWith(
                  scanMode: v ? ScanMode.rowColumn : ScanMode.linear,
                ),
              ),
            ),
            _MsSlider(
              label: 'Scan speed',
              suffix: 'per step',
              value: s.scanInterval,
              min: 300,
              max: 4000,
              onChanged: (Duration d) =>
                  controller.save(s.copyWith(scanInterval: d)),
            ),
          ],

          if (s.inputMethod == InputMethod.dwell)
            _MsSlider(
              label: 'Dwell time',
              suffix: 'to select',
              value: s.dwell,
              min: 200,
              max: 3000,
              onChanged: (Duration d) => controller.save(s.copyWith(dwell: d)),
            ),

          const _Heading('Tremor filter'),
          _MsSlider(
            label: 'Ignore repeats within',
            suffix: '',
            value: s.debounce,
            min: 0,
            max: 1500,
            onChanged: (Duration d) => controller.save(s.copyWith(debounce: d)),
          ),

          const _Heading('Voice'),
          SwitchListTile(
            value: s.speakEachWord,
            title: const Text('Speak each word as it is chosen'),
            onChanged: (bool v) =>
                controller.save(s.copyWith(speakEachWord: v)),
          ),
          ListTile(
            title: const Text('Speech rate'),
            subtitle: Slider(
              value: s.speechRate,
              min: 0.1,
              max: 1.0,
              divisions: 18,
              label: s.speechRate.toStringAsFixed(2),
              onChanged: (double v) =>
                  controller.save(s.copyWith(speechRate: v)),
            ),
          ),

          const _Heading('Vocabulary'),
          packs.when(
            loading: () => const ListTile(title: Text('Loading packs...')),
            error: (Object e, StackTrace _) =>
                ListTile(title: Text('No packs found: $e')),
            data: (List<PackSummary> list) => Column(
              children: <Widget>[
                for (final PackSummary p in list)
                  RadioListTile<String>(
                    value: p.locale,
                    groupValue: s.locale,
                    title: Text(p.name),
                    subtitle: Text('${p.tileCount} words · voice ${p.voice}'),
                    onChanged: (String? v) {
                      if (v != null) controller.setLocale(v);
                    },
                  ),
              ],
            ),
          ),

          const _Heading('Privacy'),
          SwitchListTile(
            value: s.logUtterances,
            title: const Text('Record usage on this device'),
            subtitle: const Text(
              'Off by default. Used only for the progress report. Stored on '
              'this device, never uploaded, and erasable in one tap.',
            ),
            onChanged: (bool v) => controller.setLogging(enabled: v),
          ),
        ],
      ),
    );
  }

  String _inputMethodTitle(InputMethod m) => switch (m) {
        InputMethod.touch => 'Touch',
        InputMethod.dwell => 'Dwell / hold',
        InputMethod.oneSwitch => 'One switch (auto-scan)',
        InputMethod.twoSwitch => 'Two switches (step and select)',
      };

  String _inputMethodBlurb(InputMethod m) => switch (m) {
        InputMethod.touch => 'Tap a tile directly.',
        InputMethod.dwell => 'Rest on a tile and it fires after a delay.',
        InputMethod.oneSwitch =>
          'The highlight moves on its own; the switch selects. '
              'Space or volume-down also works.',
        InputMethod.twoSwitch =>
          'One switch advances, one selects. No timing pressure at all.',
      };
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Colors.black54,
          ),
        ),
      );
}

class _MsSlider extends StatelessWidget {
  const _MsSlider({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String suffix;
  final Duration value;
  final double min;
  final double max;
  final void Function(Duration) onChanged;

  @override
  Widget build(BuildContext context) {
    final double ms = value.inMilliseconds.toDouble().clamp(min, max);
    return ListTile(
      title: Text('$label — ${ms.round()} ms $suffix'.trim()),
      subtitle: Slider(
        value: ms,
        min: min,
        max: max,
        divisions: ((max - min) / 100).round().clamp(1, 100),
        label: '${ms.round()} ms',
        onChanged: (double v) =>
            onChanged(Duration(milliseconds: v.round())),
      ),
    );
  }
}
