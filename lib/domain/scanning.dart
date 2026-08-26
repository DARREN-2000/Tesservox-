/// Scanning input, as a pure state machine.
///
/// Single-switch users cannot point. The app moves the highlight for them and
/// they press once when it lands on what they want. Getting this wrong means a
/// person says the wrong thing and cannot tell you why, so this file has no
/// Flutter imports and no timers: it is fully deterministic and unit-testable.
/// The timer lives in `access/scan_engine.dart`.
library;

/// How the highlight walks the grid.
enum ScanMode {
  /// One cell at a time, left to right, top to bottom. Slow but needs no
  /// two-stage selection, which suits new or cognitively loaded users.
  linear,

  /// Scan whole rows, select a row, then scan cells inside it. Far fewer steps
  /// on a large grid: O(rows + cols) instead of O(rows * cols).
  rowColumn,
}

/// Which stage of row-column scanning we are in.
enum ScanLevel { row, cell }

/// Immutable position of the scanning highlight.
class ScanCursor {
  const ScanCursor({
    required this.level,
    required this.row,
    required this.col,
  });

  const ScanCursor.origin()
      : level = ScanLevel.row,
        row = 0,
        col = 0;

  final ScanLevel level;
  final int row;
  final int col;

  ScanCursor copyWith({ScanLevel? level, int? row, int? col}) => ScanCursor(
        level: level ?? this.level,
        row: row ?? this.row,
        col: col ?? this.col,
      );

  @override
  bool operator ==(Object other) =>
      other is ScanCursor &&
      other.level == level &&
      other.row == row &&
      other.col == col;

  @override
  int get hashCode => Object.hash(level, row, col);

  @override
  String toString() => 'ScanCursor(${level.name}, r$row, c$col)';
}

/// Deterministic scanner over a [rows] x [cols] grid.
///
/// Drive it with [advance] (an auto-scan tick, or a "next" switch press) and
/// [select] (a "select" switch press). Nothing here is async, so tests explore
/// thousands of input sequences in milliseconds instead of sleeping.
class Scanner {
  Scanner({
    required this.rows,
    required this.cols,
    this.mode = ScanMode.rowColumn,
  })  : assert(rows > 0, 'a grid needs at least one row'),
        assert(cols > 0, 'a grid needs at least one column');

  final int rows;
  final int cols;
  final ScanMode mode;

  ScanCursor _cursor = const ScanCursor.origin();

  ScanCursor get cursor => _cursor;

  int get cellCount => rows * cols;

  /// True while a whole row is highlighted rather than a single cell.
  bool get isAtRowLevel =>
      mode == ScanMode.rowColumn && _cursor.level == ScanLevel.row;

  /// Flat indices currently highlighted. A whole row while scanning rows, one
  /// cell once we have drilled in. The UI renders exactly this, so "what is
  /// highlighted" is never duplicated logic.
  List<int> get highlighted {
    if (!isAtRowLevel) {
      return <int>[_flatten(_cursor.row, _cursor.col)];
    }
    return List<int>.generate(cols, (int c) => _flatten(_cursor.row, c));
  }

  /// One auto-scan tick, or a press of the "next" switch.
  void advance() {
    if (mode == ScanMode.linear) {
      final int next = (_flatten(_cursor.row, _cursor.col) + 1) % cellCount;
      _cursor = ScanCursor(
        level: ScanLevel.cell,
        row: next ~/ cols,
        col: next % cols,
      );
      return;
    }

    _cursor = switch (_cursor.level) {
      ScanLevel.row => _cursor.copyWith(row: (_cursor.row + 1) % rows),
      ScanLevel.cell => _cursor.copyWith(col: (_cursor.col + 1) % cols),
    };
  }

  /// A press of the "select" switch.
  ///
  /// Returns the chosen flat cell index, or null when the press only drilled
  /// from row level down into cell level. After a real selection the cursor
  /// always returns to [ScanCursor.origin] so the next utterance starts from a
  /// predictable place -- motor learning depends on that.
  int? select() {
    if (isAtRowLevel) {
      _cursor = _cursor.copyWith(level: ScanLevel.cell, col: 0);
      return null;
    }
    final int index = _flatten(_cursor.row, _cursor.col);
    reset();
    return index;
  }

  /// Back out to the start. Used by the long-press escape and by the idle
  /// timeout, so a user who loses track is never stranded inside a row.
  void reset() => _cursor = const ScanCursor.origin();

  int _flatten(int row, int col) => row * cols + col;
}
