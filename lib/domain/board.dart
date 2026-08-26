/// Vocabulary model.
///
/// A board is a fixed grid. Tiles do **not** reflow, sort or reorder, ever.
/// Competent AAC use is motor learning: the user reaches for "want" because
/// their hand knows where "want" is. A clever adaptive layout would be a
/// regression, not a feature.
library;

/// Fitzgerald key groups.
///
/// The colour convention is not decoration -- speech and language therapists
/// already teach it, and paper boards in the same classroom use it. Inventing
/// our own palette would make Vaani harder to learn, not prettier.
enum WordClass {
  /// Yellow: pronouns and people.
  people,

  /// Green: verbs.
  action,

  /// Blue: adjectives, adverbs, quantity.
  describer,

  /// Orange: nouns.
  noun,

  /// Pink: social words and politeness.
  social,

  /// Purple: question words.
  question,
}

WordClass wordClassFromName(String name) => WordClass.values.firstWhere(
      (WordClass c) => c.name == name,
      orElse: () => WordClass.noun,
    );

/// One button.
class Tile {
  const Tile({
    required this.id,
    required this.label,
    required this.spoken,
    required this.glyph,
    required this.wordClass,
  });

  factory Tile.fromJson(Map<String, dynamic> json) => Tile(
        id: json['id'] as String,
        label: json['label'] as String,
        spoken: json['speak'] as String,
        glyph: json['glyph'] as String,
        wordClass: wordClassFromName(json['class'] as String),
      );

  /// Stable across locales and across edits. Sync ops and usage analytics key
  /// on this, never on the label -- otherwise translating a board would look
  /// like deleting every word and creating new ones.
  final String id;

  /// What the user reads on the button.
  final String label;

  /// What the voice says. Often differs from [label]: inflection, politeness
  /// register, or a label short enough to fit a 96px tile.
  final String spoken;

  /// Placeholder glyph until a licensed symbol set is wired in. See
  /// ASSETS-LICENSE.md -- symbol licensing decides this, not aesthetics.
  final String glyph;

  final WordClass wordClass;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'speak': spoken,
        'glyph': glyph,
        'class': wordClass.name,
      };

  @override
  String toString() => 'Tile($id: $label)';
}

/// A compiled, locale-specific vocabulary pack.
class VocabularyPack {
  const VocabularyPack({
    required this.locale,
    required this.name,
    required this.voice,
    required this.rows,
    required this.cols,
    required this.tiles,
  });

  factory VocabularyPack.fromJson(Map<String, dynamic> json) => VocabularyPack(
        locale: json['locale'] as String,
        name: json['name'] as String,
        voice: json['voice'] as String,
        rows: json['rows'] as int,
        cols: json['cols'] as int,
        tiles: (json['tiles'] as List<dynamic>)
            .map((dynamic t) => Tile.fromJson(t as Map<String, dynamic>))
            .toList(growable: false),
      );

  /// BCP 47 tag, e.g. `en`, `ta`, `de`.
  final String locale;
  final String name;

  /// Preferred platform voice, e.g. `ta-IN`. When the OS has no voice for this
  /// locale we fall back to a bundled offline voice -- that is the whole reason
  /// this project exists.
  final String voice;

  final int rows;
  final int cols;
  final List<Tile> tiles;

  int get cellCount => rows * cols;

  Tile? tileAt(int index) =>
      index >= 0 && index < tiles.length ? tiles[index] : null;

  /// The core word list this pack teaches, used by the coverage report.
  List<String> get coreWordIds =>
      tiles.map((Tile t) => t.id).toList(growable: false);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'locale': locale,
        'name': name,
        'voice': voice,
        'rows': rows,
        'cols': cols,
        'tiles': tiles.map((Tile t) => t.toJson()).toList(),
      };
}
