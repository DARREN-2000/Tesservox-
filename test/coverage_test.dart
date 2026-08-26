import 'package:flutter_test/flutter_test.dart';
import 'package:tesservox/domain/coverage.dart';
import 'package:tesservox/domain/utterance.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 19);
  final DateTime weekAgo = now.subtract(const Duration(days: 7));

  Utterance said(List<String> ids, {Duration ago = Duration.zero}) => Utterance(
        tileIds: ids,
        spokenAt: now.subtract(ago),
        locale: 'en',
      );

  const List<String> core = <String>['i', 'want', 'more', 'water', 'help'];

  test('coverage is the share of core words the person actually reached', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: <Utterance>[
        said(<String>['i', 'want', 'water']),
        said(<String>['more', 'water'], ago: const Duration(days: 2)),
      ],
      since: weekAgo,
    );

    expect(report.used.length, 4);
    expect(report.unused.map((CoverageRow r) => r.tileId), <String>['help']);
    expect(report.coverage, closeTo(0.8, 1e-9));
  });

  test('utterances older than the window are ignored', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: <Utterance>[
        said(<String>['i', 'want'], ago: const Duration(days: 30)),
        said(<String>['water']),
      ],
      since: weekAgo,
    );

    expect(report.utteranceCount, 1);
    expect(report.used.map((CoverageRow r) => r.tileId), <String>['water']);
  });

  test('an empty log reports zero without dividing by zero', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: const <Utterance>[],
      since: weekAgo,
    );

    expect(report.utteranceCount, 0);
    expect(report.coverage, 0);
    expect(report.meanUtteranceLength, 0);
    expect(report.longestUtterance, 0);
  });

  test('nextTargets lists unreached words, so it is a therapy plan', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: <Utterance>[
        said(<String>['i']),
        said(<String>['i', 'want']),
      ],
      since: weekAgo,
    );

    expect(report.nextTargets(limit: 2), <String>['help', 'more']);
    expect(report.nextTargets(), hasLength(3));
    expect(report.nextTargets(), isNot(contains('i')));
  });

  test('rows are ordered least-used first', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: <Utterance>[
        said(<String>['i', 'i', 'i']),
        said(<String>['want']),
      ],
      since: weekAgo,
    );

    final List<int> counts =
        report.rows.map((CoverageRow r) => r.timesUsed).toList();
    expect(counts, orderedEquals(<int>[0, 0, 0, 1, 3]));
    expect(report.rows.last.tileId, 'i');
  });

  test('words the board does not contain never appear in the report', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: <Utterance>[
        said(<String>['i', 'banana', 'helicopter']),
      ],
      since: weekAgo,
    );

    // The report measures this person's reach, not the board's size.
    expect(report.rows, hasLength(core.length));
    expect(
      report.rows.map((CoverageRow r) => r.tileId),
      isNot(contains('banana')),
    );
  });

  test('mean and longest length are the headline AAC progress metrics', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: <Utterance>[
        said(<String>['i']),
        said(<String>['i', 'want']),
        said(<String>['i', 'want', 'more', 'water']),
      ],
      since: weekAgo,
    );

    expect(report.longestUtterance, 4);
    expect(report.meanUtteranceLength, closeTo(7 / 3, 1e-9));
  });

  test('lastUsed tracks the most recent use, not the first', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: <String>['water'],
      utterances: <Utterance>[
        said(<String>['water'], ago: const Duration(days: 5)),
        said(<String>['water'], ago: const Duration(days: 1)),
      ],
      since: weekAgo,
    );

    expect(report.rows.single.timesUsed, 2);
    expect(report.rows.single.lastUsed, now.subtract(const Duration(days: 1)));
  });

  test('csv has a header and one row per core word', () {
    final CoverageReport report = CoverageReport.build(
      coreTileIds: core,
      utterances: <Utterance>[said(<String>['i'])],
      since: weekAgo,
    );

    final List<String> lines = report
        .toCsv()
        .trim()
        .split('\n')
        .map((String line) => line.trim())
        .toList();

    expect(lines.first, 'tile_id,times_used,last_used');
    expect(lines, hasLength(core.length + 1));
  });
}
