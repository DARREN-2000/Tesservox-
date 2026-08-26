import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../access/accessibility_controller.dart';
import '../domain/board.dart';

/// Fitzgerald key colours.
///
/// These specific hues match the paper boards and the commercial apps a user
/// may already know. Do not "improve" them: a person who learned that verbs
/// are green has that encoded as motor and visual habit.
Color wordClassColor(WordClass wordClass) => switch (wordClass) {
      WordClass.people => const Color(0xFFFFE082),
      WordClass.action => const Color(0xFFA5D6A7),
      WordClass.describer => const Color(0xFF90CAF9),
      WordClass.noun => const Color(0xFFFFCC80),
      WordClass.social => const Color(0xFFF48FB1),
      WordClass.question => const Color(0xFFCE93D8),
    };

/// One tile on the speak grid.
///
/// Accessibility notes that are easy to get wrong:
///   * The [Semantics] label is the *word*, not "button, tile 14 of 30".
///   * [ExcludeSemantics] hides the decorative glyph so TalkBack does not read
///     "grinning face" before the word.
///   * The highlight ring is a thick outline plus a scale change, never colour
///     alone -- roughly 1 in 12 men cannot rely on a colour cue.
///   * [RepaintBoundary] keeps a moving scan highlight from repainting the
///     other 29 tiles every tick.
class TileButton extends StatelessWidget {
  const TileButton({
    required this.tile,
    required this.onPressed,
    this.highlighted = false,
    super.key,
  });

  final Tile tile;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color background = wordClassColor(tile.wordClass);

    void handlePress() {
      HapticFeedback.lightImpact();
      onPressed();
    }

    return RepaintBoundary(
      child: Semantics(
        label: tile.label,
        button: true,
        selected: highlighted,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 90),
          scale: highlighted ? 1.04 : 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(12),
              child: DwellDetector(
                onTrigger: handlePress,
                child: InkWell(
                  onTap: handlePress,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: highlighted
                          ? const Color(0xFF102A43)
                          : Colors.black12,
                      width: highlighted ? 5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ExcludeSemantics(
                      child: Text(
                        tile.glyph,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        tile.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF102A43),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An empty grid slot. Still occupies space so that tiles never shift.
class EmptyTile extends StatelessWidget {
  const EmptyTile({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SizedBox.expand(),
        ),
      );
}
