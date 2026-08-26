import 'utterance.dart';

/// Core-word coverage: the metric speech and language therapists actually ask
/// for, and which today they count by hand off a video recording.
///
/// Pure functions over a list of [Utterance]. No database, no Flutter, so the
/// arithmetic that goes into a clinical conversation is directly testable.
library;

class CoverageRow {
  const CoverageRow({
    required this.tileId,
    required this.timesUsed,
    this.lastUsed,
  });

  final String tileId;
  final int timesUsed;
  final DateTime? lastUsed;

  bool get wasUsed => timesUsed > 0;
}

class CoverageReport {
  const CoverageReport._({
    required this.rows,
    required this.since,
    required this.utteranceCount,
    required this.longestUtterance,
    required this.meanUtteranceLength,
  });

  /// Build a report for the window starting at [since].
  ///
  /// [coreTileIds] is the vocabulary we are measuring against, so a word the
  /// board does not contain can never count as "missing" -- the report measures
  /// the person's reach, not the board's size.
  factory CoverageReport.build({
    required List<String> coreTileIds,
    required List<Utterance> utterances,
    required DateTime since,
  }) {
    final Map<String, int> counts = <String, int>{};
    final Map<String, DateTime> last = <String, DateTime>{};
    int considered = 0;
    int longest = 0;
    int totalWords = 0;

    for (final Utterance u in utterances) {
      if (u.spokenAt.isBefore(since)) continue;
      considered++;
      totalWords += u.length;
      if (u.length > longest) longest = u.length;

      for (final String id in u.tileIds) {
        counts[id] = (counts[id] ?? 0) + 1;
        final DateTime? previous = last[id];
        if (previous == null || u.spokenAt.isAfter(previous)) {
          last[id] = u.spokenAt;
        }
      }
    }

    final List<CoverageRow> rows = coreTileIds
        .map(
          (String id) => CoverageRow(
            tileId: id,
            timesUsed: counts[id] ?? 0,
            lastUsed: last[id],
          ),
        )
        .toList()
      // Least-used first: the top of this list is next week's therapy plan.
      ..sort((CoverageRow a, CoverageRow b) {
        final int byCount = a.timesUsed.compareTo(b.timesUsed);
        return byCount != 0 ? byCount : a.tileId.compareTo(b.tileId);
      });

    return CoverageReport._(
      rows: rows,
      since: since,
      utteranceCount: considered,
      longestUtterance: longest,
      meanUtteranceLength: considered == 0 ? 0 : totalWords / considered,
    );
  }

  final List<CoverageRow> rows;
  final DateTime since;
  final int utteranceCount;
  final int longestUtterance;
  final double meanUtteranceLength;

  List<CoverageRow> get unused =>
      rows.where((CoverageRow r) => !r.wasUsed).toList(growable: false);

  List<CoverageRow> get used =>
      rows.where((CoverageRow r) => r.wasUsed).toList(growable: false);

  /// Share of the core vocabulary the person actually reached in this window.
  double get coverage => rows.isEmpty ? 0 : used.length / rows.length;

  /// Core words never reached: the concrete, defensible answer to "what should
  /// we work on next?".
  List<String> nextTargets({int limit = 5}) => unused
      .take(limit)
      .map((CoverageRow r) => r.tileId)
      .toList(growable: false);

  /// Flat CSV for a therapist to print or paste into a report. Deliberately
  /// boring and dependency-free.
  String toCsv() {
    final StringBuffer out = StringBuffer('tile_id,times_used,last_used\n');
    for (final CoverageRow r in rows) {
      out.writeln(
        '${r.tileId},${r.timesUsed},${r.lastUsed?.toIso8601String() ?? ""}',
      );
    }
    return out.toString();
  }
}
