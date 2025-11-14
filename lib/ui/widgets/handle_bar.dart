import 'package:flutter/material.dart';

import '../ux_config.dart';

class HandleBar extends StatelessWidget {
  const HandleBar({super.key, required this.isActive, required this.handle});
  final bool isActive;
  final HandleConfig handle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = theme.colorScheme.onSurface.withValues(alpha: 0.32);
    final active = theme.colorScheme.primaryContainer;
    final color = isActive ? active : inactive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: isActive ? handle.barWidthActive : handle.barWidthInactive,
      height: handle.barHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(handle.barHeight / 2),
      ),
    );
  }
}
