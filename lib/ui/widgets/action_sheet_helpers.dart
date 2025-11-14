import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import '../ux_config.dart';
import 'create_action_sheet_content.dart';

Future<void> _showSideCreateActionSheet(BuildContext context, WidgetRef ref, DateTime targetDate, {required bool fromRight}) async {
  final registry = ref.read(widgetRegistryProvider);
  final items = registry.actionsForDate(context, targetDate);
  final ux = ref.read(uxConfigProvider);
  final cfg = ux.sideSheet;
  final size = MediaQuery.of(context).size;
  final bool isTablet = size.width >= 600;

  double base = size.width * cfg.widthFraction;
  double maxW = isTablet ? cfg.tabletMaxWidth : cfg.maxWidth;
  double width = base.clamp(cfg.minWidth, maxW);
  // Keep some margin to the far edge if possible
  final double maxAllowed = size.width - cfg.horizontalMargin;
  if (width > maxAllowed) width = maxAllowed;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    pageBuilder: (ctx, _, _) {
      final begin = Offset(fromRight ? 1 : -1, 0);
      return Align(
        alignment: fromRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          elevation: 8,
          color: Theme.of(ctx).colorScheme.surface,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: [
                CreateActionSheetContent(targetDate: targetDate),
                // Tap any empty space inside the panel to close it
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(ctx).maybePop(),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      final tween = Tween<Offset>(begin: Offset(fromRight ? 1 : -1, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: anim.drive(tween), child: child);
    },
  );
}

Future<void> showCreateActionSheet(BuildContext context, WidgetRef ref, DateTime targetDate) async {
  final ux = ref.read(uxConfigProvider);
  final handed = ref.read(handednessProvider);

  ActionSheetPresentation mode = ux.actionSheetPresentation;
  if (mode == ActionSheetPresentation.auto) {
    final size = MediaQuery.of(context).size;
    mode = size.width >= 600 ? ActionSheetPresentation.side : ActionSheetPresentation.bottom;
  }

  if (mode == ActionSheetPresentation.bottom) {
    final registry = ref.read(widgetRegistryProvider);
    final items = registry.actionsForDate(context, targetDate);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => CreateActionSheetContent(targetDate: targetDate),
    );
    return;
  }

  // Side sheet: align with handedness. Right-handed → from right (LTR/RTL nuance optional).
  final textDir = Directionality.of(context);
  bool fromRight;
  if (handed == Handedness.right) {
    fromRight = true;
  } else {
    fromRight = false;
  }
  // If in RTL, you may want to flip for conventional expectations; we prioritize handedness per request.
  await _showSideCreateActionSheet(context, ref, targetDate, fromRight: fromRight);
}
