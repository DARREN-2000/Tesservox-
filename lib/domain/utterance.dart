/// One thing the person said.
///
/// Stored by tile id, not by label, so a report survives translating or
/// relabelling a board. Logging is **off by default** and lives only on the
/// device: see `data/utterance_log.dart` and the privacy note in the README.
class Utterance {
  const Utterance({
    required this.tileIds,
    required this.spokenAt,
    required this.locale,
  });

  factory Utterance.fromJson(Map<String, dynamic> json) => Utterance(
        tileIds: (json['tiles'] as List<dynamic>)
            .map((dynamic t) => t as String)
            .toList(growable: false),
        spokenAt: DateTime.parse(json['at'] as String),
        locale: json['locale'] as String,
      );

  final List<String> tileIds;
  final DateTime spokenAt;
  final String locale;

  /// Words per utterance is the headline metric in AAC progress reporting:
  /// moving a person from one-word requests to two- and three-word
  /// combinations is usually the actual therapy goal.
  int get length => tileIds.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tiles': tileIds,
        'at': spokenAt.toIso8601String(),
        'locale': locale,
      };

  @override
  String toString() => 'Utterance(${tileIds.join(" ")} @ $spokenAt)';
}
