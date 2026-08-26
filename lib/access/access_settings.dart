import '../domain/scanning.dart';

/// How the person reaches a tile.
///
/// This is the single most important setting in the app. It is also the one
/// that changes over time -- an ALS user may move from [touch] to [dwell] to
/// [oneSwitch] within a year -- so it is a runtime setting, never a build
/// variant or a separate app.
enum InputMethod {
  /// Direct selection. Most users, most of the time.
  touch,

  /// Hover or hold for a configurable period, then it fires. For users who can
  /// point but not reliably lift and tap.
  dwell,

  /// One switch. The app auto-advances the highlight; the switch selects.
  oneSwitch,

  /// Two switches: one advances, one selects. No timing pressure at all, which
  /// matters enormously for users with variable response latency.
  twoSwitch,
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((T v) => v.name == name, orElse: () => fallback);

/// Everything about *access*, kept separate from vocabulary on purpose.
/// A therapist tunes this; a family tunes the board.
class AccessSettings {
  const AccessSettings({
    this.inputMethod = InputMethod.touch,
    this.scanMode = ScanMode.rowColumn,
    this.scanInterval = const Duration(milliseconds: 1200),
    this.dwell = const Duration(milliseconds: 800),
    this.debounce = const Duration(milliseconds: 300),
    this.speakEachWord = true,
    this.logUtterances = false,
    this.speechRate = 0.45,
    this.pitch = 1.0,
    this.locale = 'en',
  });

  factory AccessSettings.fromJson(Map<String, dynamic> json) => AccessSettings(
        inputMethod: _enumByName(
          InputMethod.values,
          json['inputMethod'],
          InputMethod.touch,
        ),
        scanMode: _enumByName(
          ScanMode.values,
          json['scanMode'],
          ScanMode.rowColumn,
        ),
        scanInterval: Duration(
          milliseconds: (json['scanIntervalMs'] as num?)?.toInt() ?? 1200,
        ),
        dwell: Duration(milliseconds: (json['dwellMs'] as num?)?.toInt() ?? 800),
        debounce:
            Duration(milliseconds: (json['debounceMs'] as num?)?.toInt() ?? 300),
        speakEachWord: json['speakEachWord'] as bool? ?? true,
        logUtterances: json['logUtterances'] as bool? ?? false,
        speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.45,
        pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
        locale: json['locale'] as String? ?? 'en',
      );

  final InputMethod inputMethod;
  final ScanMode scanMode;

  /// How long the highlight rests on each row/cell in [InputMethod.oneSwitch].
  final Duration scanInterval;

  /// Hold time before a [InputMethod.dwell] selection fires.
  final Duration dwell;

  /// Tremor filter. Two activations closer together than this are treated as
  /// one intention. Without it, a hand tremor produces "want want want".
  final Duration debounce;

  /// Speak each tile as it is added, not only the finished sentence. Most
  /// beginning communicators need this feedback; some advanced users hate it.
  final bool speakEachWord;

  /// Local usage logging for progress reports. Off unless someone turns it on.
  final bool logUtterances;

  final double speechRate;
  final double pitch;

  /// Active vocabulary pack, e.g. `en`, `ta`, `de`.
  final String locale;

  bool get isScanning =>
      inputMethod == InputMethod.oneSwitch ||
      inputMethod == InputMethod.twoSwitch;

  /// Only one-switch mode advances on a timer; two-switch never does.
  bool get autoAdvances => inputMethod == InputMethod.oneSwitch;

  AccessSettings copyWith({
    InputMethod? inputMethod,
    ScanMode? scanMode,
    Duration? scanInterval,
    Duration? dwell,
    Duration? debounce,
    bool? speakEachWord,
    bool? logUtterances,
    double? speechRate,
    double? pitch,
    String? locale,
  }) =>
      AccessSettings(
        inputMethod: inputMethod ?? this.inputMethod,
        scanMode: scanMode ?? this.scanMode,
        scanInterval: scanInterval ?? this.scanInterval,
        dwell: dwell ?? this.dwell,
        debounce: debounce ?? this.debounce,
        speakEachWord: speakEachWord ?? this.speakEachWord,
        logUtterances: logUtterances ?? this.logUtterances,
        speechRate: speechRate ?? this.speechRate,
        pitch: pitch ?? this.pitch,
        locale: locale ?? this.locale,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'inputMethod': inputMethod.name,
        'scanMode': scanMode.name,
        'scanIntervalMs': scanInterval.inMilliseconds,
        'dwellMs': dwell.inMilliseconds,
        'debounceMs': debounce.inMilliseconds,
        'speakEachWord': speakEachWord,
        'logUtterances': logUtterances,
        'speechRate': speechRate,
        'pitch': pitch,
        'locale': locale,
      };
}
