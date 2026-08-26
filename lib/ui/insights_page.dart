import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board.dart';
import '../domain/coverage.dart';
import '../state/providers.dart';

/// The progress report a speech and language therapist currently produces by
/// hand, from video, with a tally sheet.
///
/// Everything here is computed on device from the local log. There is no
/// analytics SDK in this project and there never will be.
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VocabularyPack> packAsync = ref.watch(packProvider);
    final bool logging = ref.watch(settingsProvider).logUtterances;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: packAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('$e')),
        data: (VocabularyPack pack) {
          final CoverageReport report = CoverageReport.build(
            coreTileIds: pack.coreWordIds,
            utterances: ref.read(utteranceLogProvider).entries,
            since: DateTime.now().subtract(const Duration(days: 7)),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (!logging)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.visibility_off_outlined),
                    title: Text('Recording is off'),
                    subtitle: Text(
                      'Nothing is being logged, so this report will stay '
                      'empty. Turn it on in Access › Privacy if a therapist '
                      'needs it.',
                    ),
                  ),
                ),
              _Metric(
                label: 'Core words reached this week',
                value: '${(report.coverage * 100).round()}%',
                detail:
                    '${report.used.length} of ${report.rows.length} words',
              ),
              _Metric(
                label: 'Longest utterance',
                value: '${report.longestUtterance}',
                detail: 'words in one message',
              ),
              _Metric(
                label: 'Mean utterance length',
                value: report.meanUtteranceLength.toStringAsFixed(1),
                detail: '${report.utteranceCount} messages spoken',
              ),
              const SizedBox(height: 16),
              const Text(
                'Suggested next targets',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Core words this person has not reached in the last 7 days.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              if (report.nextTargets().isEmpty)
                const Text('Every core word was used. Time for a bigger board.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String id in report.nextTargets(limit: 8))
                      Chip(label: Text(_labelFor(pack, id))),
                  ],
                ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Erase all recorded usage'),
                onPressed: () => _confirmErase(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  String _labelFor(VocabularyPack pack, String tileId) => pack.tiles
      .firstWhere(
        (Tile t) => t.id == tileId,
        orElse: () => Tile(
          id: tileId,
          label: tileId,
          spoken: tileId,
          glyph: '',
          wordClass: WordClass.noun,
        ),
      )
      .label;

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Erase recorded usage?'),
        content: const Text('This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(utteranceLogProvider).clear();
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(label),
          subtitle: Text(detail),
          trailing: Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
