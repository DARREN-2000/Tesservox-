import 'package:flutter/material.dart';

import '../domain/board.dart';
import 'tile_button.dart';

/// The sentence under construction.
///
/// Sits at the top and is large, because the person the user is talking *to*
/// reads it, often upside down across a table.
class MessageBar extends StatelessWidget {
  const MessageBar({
    required this.tiles,
    required this.onSpeak,
    required this.onBackspace,
    required this.onClear,
    super.key,
  });

  final List<Tile> tiles;
  final VoidCallback onSpeak;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final String text = tiles.map((Tile t) => t.label).join(' ');

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: text.isEmpty ? 'Message empty' : text,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: <Widget>[
                      for (final Tile tile in tiles)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            backgroundColor: wordClassColor(tile.wordClass),
                            label: Text(
                              tile.label,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _Action(
            icon: Icons.backspace_outlined,
            tooltip: 'Delete last word',
            onPressed: tiles.isEmpty ? null : onBackspace,
          ),
          _Action(
            icon: Icons.clear,
            tooltip: 'Clear message',
            onPressed: tiles.isEmpty ? null : onClear,
          ),
          const SizedBox(width: 4),
          // Deliberately the biggest target on the screen.
          SizedBox(
            width: 96,
            height: 60,
            child: FilledButton.icon(
              onPressed: tiles.isEmpty ? null : onSpeak,
              icon: const Icon(Icons.volume_up),
              label: const Text('Say'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon),
        iconSize: 30,
        tooltip: tooltip,
        onPressed: onPressed,
      );
}
