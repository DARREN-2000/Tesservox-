import 'package:flutter_tts/flutter_tts.dart';

/// What the app needs from a voice.
///
/// Deliberately narrow. The whole premise of Vaani is that this interface will
/// eventually have a third implementation -- a bundled offline neural voice via
/// `dart:ffi` -- for the languages platform TTS simply does not ship.
abstract class Speaker {
  /// Speak [text]. Must not throw: a failed voice should be silent, never a
  /// crash, because a crash takes away someone's ability to communicate.
  Future<void> speak(
    String text, {
    required String voiceLocale,
    double rate,
    double pitch,
  });

  Future<void> stop();

  /// Whether the platform can actually say this locale. When false, the UI
  /// shows an honest warning instead of silently speaking English phonetics
  /// over Tamil text.
  Future<bool> supports(String voiceLocale);
}

/// Platform TTS. Good enough for major languages, absent for many others.
class PlatformSpeaker implements Speaker {
  PlatformSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(
    String text, {
    required String voiceLocale,
    double rate = 0.45,
    double pitch = 1.0,
  }) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage(voiceLocale);
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
      await _tts.speak(text);
    } on Object catch (_) {
      // Swallow deliberately. See the contract on [Speaker.speak].
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (_) {
      // Nothing useful to do if the engine is already gone.
    }
  }

  @override
  Future<bool> supports(String voiceLocale) async {
    try {
      final Object? available = await _tts.isLanguageAvailable(voiceLocale);
      return available == true;
    } on Object catch (_) {
      return false;
    }
  }
}

/// Records instead of speaking. Used by widget tests so the suite never needs
/// an audio device.
class RecordingSpeaker implements Speaker {
  final List<String> spoken = <String>[];
  int stopCount = 0;

  @override
  Future<void> speak(
    String text, {
    required String voiceLocale,
    double rate = 0.45,
    double pitch = 1.0,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<bool> supports(String voiceLocale) async => true;
}

// ---------------------------------------------------------------------------
// ROADMAP: OfflineSpeaker
//
// The reason this project exists. Platform TTS has no usable voice for most of
// the world's languages, so a bundled engine is not an optimisation -- it is
// the feature.
//
// Plan:
//   1. Cross-compile Piper (or eSpeak-NG for a smaller footprint) for
//      arm64-v8a, armeabi-v7a and x86_64.
//   2. Bind it with `dart:ffi` and run synthesis inside an `Isolate` so a
//      300ms synth never drops a frame on the speak grid.
//   3. Cache synthesised PCM by hash(text + voice + rate); AAC users repeat
//      the same phrases constantly, so hit rates are very high.
//   4. Publish time-to-first-audio per language on three real devices. That
//      benchmark table is the proof this works, not a screenshot.
// ---------------------------------------------------------------------------
