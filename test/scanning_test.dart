import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaani/domain/scanning.dart';

void main() {
  group('row-column scanning', () {
    test('starts by highlighting the whole first row', () {
      final Scanner scanner = Scanner(rows: 5, cols: 6);
      expect(scanner.isAtRowLevel, isTrue);
      expect(scanner.highlighted, <int>[0, 1, 2, 3, 4, 5]);
    });

    test('advance walks whole rows, then wraps', () {
      final Scanner scanner = Scanner(rows: 3, cols: 2);
      expect(scanner.highlighted, <int>[0, 1]);
      scanner.advance();
      expect(scanner.highlighted, <int>[2, 3]);
      scanner.advance();
      expect(scanner.highlighted, <int>[4, 5]);
      scanner.advance();
      expect(
        scanner.highlighted,
        <int>[0, 1],
        reason: 'scanning must never reach a dead end',
      );
    });

    test('selecting a row drills into cells and returns nothing yet', () {
      final Scanner scanner = Scanner(rows: 3, cols: 4);
      scanner.advance(); // row 1
      expect(scanner.select(), isNull);
      expect(scanner.isAtRowLevel, isFalse);
      expect(scanner.highlighted, <int>[4]);
    });

    test('selecting a cell returns its flat index and resets', () {
      final Scanner scanner = Scanner(rows: 3, cols: 4);
      scanner.advance(); // row 1
      scanner.select(); // drill in at col 0
      scanner.advance(); // col 1
      scanner.advance(); // col 2
      expect(scanner.select(), 6);
      expect(scanner.cursor, const ScanCursor.origin());
    });

    test('row-column is far cheaper than linear on a real board', () {
      // 5x6: 11 presses worst case instead of 30. At a 1.2 s scan interval
      // that is a 13-second word instead of a 36-second word, which is the
      // difference between having a conversation and not having one.
      final Scanner scanner = Scanner(rows: 5, cols: 6);
      int presses = 0;
      while (scanner.highlighted.first != 24) {
        scanner.advance();
        presses++;
      }
      presses++;
      scanner.select(); // drill into the last row
      while (scanner.highlighted.single != 29) {
        scanner.advance();
        presses++;
      }
      presses++;
      expect(scanner.select(), 29);
      expect(presses, lessThanOrEqualTo(11));
    });

    test('a single-column grid still works and never gets stuck', () {
      final Scanner scanner = Scanner(rows: 4, cols: 1);
      expect(scanner.highlighted, <int>[0]);
      expect(scanner.select(), isNull);
      expect(scanner.select(), 0);
    });
  });

  group('linear scanning', () {
    test('walks one cell at a time and wraps at the end', () {
      final Scanner scanner = Scanner(rows: 2, cols: 2, mode: ScanMode.linear);
      expect(scanner.highlighted, <int>[0]);
      scanner.advance();
      expect(scanner.highlighted, <int>[1]);
      scanner.advance();
      expect(scanner.highlighted, <int>[2]);
      scanner.advance();
      expect(scanner.highlighted, <int>[3]);
      scanner.advance();
      expect(scanner.highlighted, <int>[0]);
    });

    test('one press selects, with no drill-in stage', () {
      final Scanner scanner = Scanner(rows: 2, cols: 3, mode: ScanMode.linear);
      scanner.advance();
      expect(scanner.select(), 1);
    });
  });

  test('property: no switch sequence can produce an invalid state', () {
    // A single-switch user cannot see or correct a bad index. They just say the
    // wrong word and cannot tell you why. So this invariant is checked over
    // hundreds of pseudo-random press sequences rather than a few examples.
    // The seed is fixed, so a CI failure is reproducible.
    final Random random = Random(20260820);

    for (int trial = 0; trial < 400; trial++) {
      final int rows = 1 + random.nextInt(6);
      final int cols = 1 + random.nextInt(6);
      final ScanMode mode =
          random.nextBool() ? ScanMode.linear : ScanMode.rowColumn;
      final Scanner scanner = Scanner(rows: rows, cols: cols, mode: mode);

      for (int step = 0; step < 120; step++) {
        if (random.nextBool()) {
          scanner.advance();
        } else {
          final int? selected = scanner.select();
          if (selected != null) {
            expect(selected, inInclusiveRange(0, scanner.cellCount - 1));
            expect(
              scanner.cursor,
              const ScanCursor.origin(),
              reason: 'every utterance must start from the same place',
            );
          }
        }

        expect(
          scanner.highlighted,
          isNotEmpty,
          reason: 'something is always highlighted, or the user is lost',
        );
        for (final int index in scanner.highlighted) {
          expect(index, inInclusiveRange(0, scanner.cellCount - 1));
        }
        expect(scanner.cursor.row, inInclusiveRange(0, rows - 1));
        expect(scanner.cursor.col, inInclusiveRange(0, cols - 1));
      }
    }
  });
}
