import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'access_settings.dart';

/// Provides global accessibility interactions, specifically for dwell logic.
final accessibilityControllerProvider = Provider<AccessibilityController>((ref) {
  final settings = ref.watch(settingsProvider);
  return AccessibilityController(settings: settings);
});

/// Controller that manages advanced accessibility states like dwell timing.
class AccessibilityController {
  AccessibilityController({required this.settings});

  final AccessSettings settings;
}

/// A widget that enables dwell (dwell selection) interactions.
///
/// When [InputMethod.dwell] is active, resting the pointer on this widget
/// for the [AccessSettings.dwell] duration will automatically trigger [onTrigger].
class DwellDetector extends ConsumerStatefulWidget {
  const DwellDetector({
    required this.child,
    required this.onTrigger,
    super.key,
  });

  final Widget child;
  final VoidCallback onTrigger;

  @override
  ConsumerState<DwellDetector> createState() => _DwellDetectorState();
}

class _DwellDetectorState extends ConsumerState<DwellDetector> {
  Timer? _dwellTimer;
  bool _isHovering = false;

  void _handleEnter() {
    final settings = ref.read(settingsProvider);
    if (settings.inputMethod != InputMethod.dwell) return;

    _isHovering = true;
    _dwellTimer?.cancel();
    _dwellTimer = Timer(settings.dwell, () {
      if (_isHovering && mounted) {
        widget.onTrigger();
      }
    });
  }

  void _handleExit() {
    _isHovering = false;
    _dwellTimer?.cancel();
    _dwellTimer = null;
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleEnter(),
      onExit: (_) => _handleExit(),
      child: widget.child,
    );
  }
}
