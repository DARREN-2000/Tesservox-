import 'package:flutter/foundation.dart';

/// Represents a multi-word phrase or script saved for instant triggering.
/// Gestalt language processors often communicate using full phrases rather
/// than assembling words one by one.
@immutable
class GestaltPhrase {
  const GestaltPhrase({
    required this.id,
    required this.text,
    this.label,
  });

  /// Unique identifier for the phrase.
  final String id;

  /// The full multi-word script or phrase.
  final String text;

  /// Optional shorter label for display purposes (e.g., "I need a break").
  final String? label;

  /// Returns the text to display.
  String get displayText => label ?? text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GestaltPhrase &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          label == other.label;

  @override
  int get hashCode => id.hashCode ^ text.hashCode ^ label.hashCode;
}

/// A repository for managing [GestaltPhrase]s.
class GestaltBank extends ChangeNotifier {
  GestaltBank({List<GestaltPhrase>? initialPhrases})
      : _phrases = initialPhrases ?? [];

  final List<GestaltPhrase> _phrases;

  List<GestaltPhrase> get phrases => List.unmodifiable(_phrases);

  void addPhrase(GestaltPhrase phrase) {
    _phrases.add(phrase);
    notifyListeners();
  }

  void removePhrase(String id) {
    _phrases.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
