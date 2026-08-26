import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/scanning.dart';
import 'access_settings.dart';

/// Connects the pure [Scanner] to real time and real switch presses.
///
/// Everything time-dependent or stateful lives here so that `domain/scanning`
/// stays a pure function of its inputs. This class is the only place a
/// [Timer] exists, and the only place a tremor filter is applied.
class ScanEngine extends ChangeNotifier {
  ScanEngine({
    required AccessSettings settings,
    required int rows,
    required int cols,
    required void Function(int index) onSelect,
    DateTime Function()? clock,
  })  : _settings = settings,
        _onSelect = onSelect,
        _clock = clock ?? DateTime.now,
        _scanner = Scanner(rows: rows, cols: cols, mode: settings.scanMode) {
    _syncTimer();
  }

  AccessSettings _settings;
  final void Function(int index) _onSelect;

  /// Injectable so debounce behaviour is testable without sleeping.
  final DateTime Function() _clock;

  Scanner _scanner;
  Timer? _timer;
  DateTime? _lastActivation;

  bool get isScanning => _settings.isScanning;

  /// Empty unless a scanning input method is active, so the UI does not have to
  /// know the rules.
  List<int> get highlighted =>
      _settings.isScanning ? _scanner.highlighted : const <int>[];

  bool get isAtRowLevel => _scanner.isAtRowLevel;

  /// Re-key the scanner when the grid or the mode changes. Rebuilding the
  /// scanner rather than mutating it means the cursor can never point outside
  /// the grid after a pack switch.
  ///
  /// Deliberately does NOT call [notifyListeners]. This is called from
  /// `didUpdateWidget`, i.e. during a build pass, and notifying there would
  /// throw "markNeedsBuild() called during build". The caller is already
  /// rebuilding and will read the new state.
  void reconfigure({
    required AccessSettings settings,
    required int rows,
    required int cols,
  }) {
    final bool geometryChanged =
        rows != _scanner.rows || cols != _scanner.cols;
    final bool modeChanged = settings.scanMode != _settings.scanMode;
    final bool timingChanged =
        settings.scanInterval != _settings.scanInterval ||
            settings.inputMethod != _settings.inputMethod;

    _settings = settings;
    if (geometryChanged || modeChanged) {
      _scanner = Scanner(rows: rows, cols: cols, mode: settings.scanMode);
    }
    if (timingChanged || geometryChanged || modeChanged) {
      _syncTimer();
    }
  }

  /// "Next" switch, or an auto-scan tick.
  void pressNext() {
    if (!_settings.isScanning || !_accept()) return;
    _scanner.advance();
    notifyListeners();
  }

  /// "Select" switch.
  void pressSelect() {
    if (!_settings.isScanning || !_accept()) return;
    final int? index = _scanner.select();
    notifyListeners();
    // Fire after notifying so the highlight has already reset if the callback
    // rebuilds the tree.
    if (index != null) _onSelect(index);
  }

  /// Escape hatch for a user who has lost track inside a row.
  void escape() {
    _scanner.reset();
    notifyListeners();
  }

  /// Tremor filter. Returns false when this activation arrived too soon after
  /// the previous one to be a separate intention.
  bool _accept() {
    final DateTime now = _clock();
    final DateTime? last = _lastActivation;
    if (last != null && now.difference(last) < _settings.debounce) {
      return false;
    }
    _lastActivation = now;
    return true;
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_settings.autoAdvances) return;
    _timer = Timer.periodic(_settings.scanInterval, (Timer _) {
      // Auto-advance bypasses the tremor filter: it is not user input.
      _scanner.advance();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
