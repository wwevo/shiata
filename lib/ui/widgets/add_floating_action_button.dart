import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'create_action_sheet.dart';

/// Floating Action Button for opening the Add Action Sheet.
/// Positioned in the lower right of pages with add capability.
class AppAddFloatingActionButton extends ConsumerWidget {
  const AppAddFloatingActionButton({
    super.key,
    required this.pageId,
    this.targetDate,
    this.getTargetDate,
    this.tooltip = 'Add',
  });

  final String pageId;
  final DateTime? targetDate;
  final DateTime Function()? getTargetDate;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: 'app_fab_$pageId',
      tooltip: tooltip,
      onPressed: () {
        final date = getTargetDate?.call() ?? targetDate ?? DateTime.now();
        showAddActionSheet(
          context: context,
          ref: ref,
          pageId: pageId,
          targetDate: date,
        );
      },
      child: const Icon(Icons.add),
    );
  }
}
