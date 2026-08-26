import 'package:flutter/material.dart';

import '../domain/board.dart';
import 'tile_button.dart';

/// The speak grid.
///
/// Geometry comes from the pack, never from the content. A German label is
/// longer than its Tamil equivalent, and if that changed the layout then
/// switching language would move every word -- which for a motor-planning user
/// is the same as deleting the board.
class BoardGrid extends StatelessWidget {
  const BoardGrid({
    required this.pack,
    required this.highlighted,
    required this.onTileTap,
    super.key,
  });

  final VocabularyPack pack;

  /// Flat indices to highlight, supplied by the scan engine.
  final List<int> highlighted;

  final void Function(Tile tile) onTileTap;

  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final Set<int> hot = highlighted.toSet();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double aspect = _aspectRatio(constraints);
        return GridView.builder(
          padding: EdgeInsets.zero,
          // The whole board must be reachable without scrolling. A scanning
          // user cannot scroll, and a scrolled-off tile is an unsayable word.
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: pack.cols,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
            childAspectRatio: aspect,
          ),
          itemCount: pack.cellCount,
          itemBuilder: (BuildContext context, int index) {
            final Tile? tile = pack.tileAt(index);
            if (tile == null) return const EmptyTile();
            return TileButton(
              tile: tile,
              highlighted: hot.contains(index),
              onPressed: () => onTileTap(tile),
            );
          },
        );
      },
    );
  }

  double _aspectRatio(BoxConstraints constraints) {
    if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
      return 1;
    }
    final double cellWidth =
        (constraints.maxWidth - _gap * (pack.cols - 1)) / pack.cols;
    final double cellHeight =
        (constraints.maxHeight - _gap * (pack.rows - 1)) / pack.rows;
    if (cellWidth <= 0 || cellHeight <= 0) return 1;
    return cellWidth / cellHeight;
  }
}
