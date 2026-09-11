import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/widgets/add_registry.dart';
import '../../domain/widgets/create_action.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../ux_config.dart';
import 'inline_time_picker.dart';

/// Shows the action sheet for adding elements on a specific page.
/// Opens as a side sheet on the right side on Linux / desktop,
/// and as a bottom panel / sheet on Android / mobile.
Future<void> showAddActionSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String pageId,
  DateTime? targetDate,
}) async {
  final addRegistry = ref.read(addRegistryProvider);
  final config = addRegistry.getConfig(pageId);
  final target = targetDate ?? DateTime.now();

  final title = config?.title ?? 'Add';
  final showTimePicker = config?.showTimePicker ?? false;
  final actions = config?.actionsBuilder(context, ref, target) ??
      ref
          .read(widgetRegistryProvider)
          .actionsForDate(context, target)
          .map((e) => e.action)
          .toList();

  await _showActionSheetGeneric(
    context: context,
    ref: ref,
    targetDate: target,
    title: title,
    showTimePicker: showTimePicker,
    actions: actions,
  );
}

/// Backwards-compatible helper for showing the create action sheet for a target date.
Future<void> showCreateActionSheet(
  BuildContext context,
  WidgetRef ref,
  DateTime targetDate, {
  List<({WidgetKind kind, CreateAction action})>? items,
}) async {
  if (items != null) {
    await _showActionSheetGeneric(
      context: context,
      ref: ref,
      targetDate: targetDate,
      title: 'Add entry',
      showTimePicker: true,
      actions: items.map((e) => e.action).toList(),
      itemsWithKind: items,
    );
    return;
  }

  await showAddActionSheet(
    context: context,
    ref: ref,
    pageId: 'active_week',
    targetDate: targetDate,
  );
}

Future<void> _showActionSheetGeneric({
  required BuildContext context,
  required WidgetRef ref,
  required DateTime targetDate,
  required String title,
  required bool showTimePicker,
  required List<CreateAction> actions,
  List<({WidgetKind kind, CreateAction action})>? itemsWithKind,
}) async {
  final ux = ref.read(uxConfigProvider);
  final platform = Theme.of(context).platform;

  final isDesktop = platform == TargetPlatform.linux ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS;
  final isAndroid = platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS;

  ActionSheetPresentation mode = ux.actionSheetPresentation;
  if (mode == ActionSheetPresentation.auto) {
    if (isAndroid) {
      mode = ActionSheetPresentation.bottom;
    } else if (isDesktop) {
      mode = ActionSheetPresentation.side;
    } else {
      final size = MediaQuery.of(context).size;
      mode = size.width >= 600
          ? ActionSheetPresentation.side
          : ActionSheetPresentation.bottom;
    }
  }

  if (mode == ActionSheetPresentation.bottom) {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => CreateActionSheetContent(
        targetDate: targetDate,
        title: title,
        showTimePicker: showTimePicker,
        actions: actions,
        itemsWithKind: itemsWithKind,
      ),
    );
    return;
  }

  // Side sheet: right side on Linux/desktop.
  await _showSideCreateActionSheet(
    context,
    ref,
    targetDate,
    title: title,
    showTimePicker: showTimePicker,
    actions: actions,
    itemsWithKind: itemsWithKind,
    fromRight: true,
  );
}

Future<void> _showSideCreateActionSheet(
  BuildContext context,
  WidgetRef ref,
  DateTime targetDate, {
  required String title,
  required bool showTimePicker,
  required List<CreateAction> actions,
  List<({WidgetKind kind, CreateAction action})>? itemsWithKind,
  required bool fromRight,
}) async {
  final ux = ref.read(uxConfigProvider);
  final cfg = ux.sideSheet;
  final size = MediaQuery.of(context).size;
  final bool isTablet = size.width >= 600;

  double base = size.width * cfg.widthFraction;
  double maxW = isTablet ? cfg.tabletMaxWidth : cfg.maxWidth;
  double width = base.clamp(cfg.minWidth, maxW);
  final double maxAllowed = size.width - cfg.horizontalMargin;
  if (width > maxAllowed) width = maxAllowed;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    pageBuilder: (ctx, _, _) {
      return Align(
        alignment: fromRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          elevation: 8,
          color: Theme.of(ctx).colorScheme.surface,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: CreateActionSheetContent(
                      targetDate: targetDate,
                      title: title,
                      showTimePicker: showTimePicker,
                      actions: actions,
                      itemsWithKind: itemsWithKind,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      final tween = Tween<Offset>(
        begin: Offset(fromRight ? 1 : -1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: anim.drive(tween), child: child);
    },
  );
}

/// Content panel rendered inside bottom or side action sheets.
class CreateActionSheetContent extends ConsumerStatefulWidget {
  const CreateActionSheetContent({
    super.key,
    required this.targetDate,
    this.title = 'Add entry',
    this.showTimePicker = false,
    this.actions,
    this.itemsWithKind,
  });

  final DateTime targetDate;
  final String title;
  final bool showTimePicker;
  final List<CreateAction>? actions;
  final List<({WidgetKind kind, CreateAction action})>? itemsWithKind;

  @override
  ConsumerState<CreateActionSheetContent> createState() =>
      _CreateActionSheetContentState();
}

class _CreateActionSheetContentState
    extends ConsumerState<CreateActionSheetContent> {
  late SectionLayout _layout;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final config = ref.read(uxConfigProvider);
    _layout = config.actionSheet.defaultLayout;
    _selectedTime = TimeOfDay.fromDateTime(widget.targetDate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ExpansibleController controller = ExpansibleController();

    // Resolve list of actions
    final List<CreateAction> actionList;
    if (widget.actions != null) {
      actionList = widget.actions!;
    } else if (widget.itemsWithKind != null) {
      actionList = widget.itemsWithKind!.map((e) => e.action).toList();
    } else {
      actionList = ref
          .read(widgetRegistryProvider)
          .actionsForDate(context, widget.targetDate)
          .map((e) => e.action)
          .toList();
    }

    final isSingleAction = actionList.length == 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (actionList.length > 1)
                    IconButton(
                      icon: Icon(
                        _layout == SectionLayout.wrap
                            ? Icons.grid_view
                            : Icons.view_agenda,
                      ),
                      onPressed: () => setState(() {
                        _layout = _layout == SectionLayout.wrap
                            ? SectionLayout.grid
                            : SectionLayout.wrap;
                      }),
                      tooltip: _layout == SectionLayout.wrap
                          ? 'Switch to grid'
                          : 'Switch to wrap',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Time picker on top for active_week / when requested
              if (widget.showTimePicker) ...[
                ExpansionTile(
                  controller: controller,
                  title: const Text('set time and date for entry'),
                  children: <Widget>[
                    InlineTimePicker(
                      initialTime: _selectedTime,
                      onTimeChanged: (t) {
                        setState(() {
                          _selectedTime = t;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ]
                ),
              ],

              /*ElevatedButton(
                child: const Text('Expand/Collapse the Tile Above'),
                onPressed: () {
                  if (controller.isExpanded) {
                    controller.collapse();
                  } else {
                    controller.expand();
                  }
                },
              ),*/

              // Actions section
              if (actionList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No actions available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else if (isSingleAction && !widget.showTimePicker)
                _buildSingleActionProminent(context, actionList.first)
              else
                _buildItemList(
                  context: context,
                  items: actionList,
                  layout: _layout,
                ),

              // Blank space at bottom for other pages
              if (!widget.showTimePicker)
                const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleActionProminent(BuildContext context, CreateAction action) {
    final theme = Theme.of(context);
    final color = action.color ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _executeAction(context, action),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  radius: 20,
                  child: Icon(action.icon, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    action.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemList({
    required BuildContext context,
    required List<CreateAction> items,
    required SectionLayout layout,
  }) {
    if (layout == SectionLayout.wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final action in items) _buildActionChip(context, action),
        ],
      );
    }

    // Grid layout with high legibility
    return LayoutBuilder(
      builder: (ctx, cons) {
        final width = cons.maxWidth;
        final col = width >= 480
            ? 3
            : width >= 320
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: col,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) => _buildGridButton(context, items[i]),
        );
      },
    );
  }

  Widget _buildActionChip(BuildContext context, CreateAction action) {
    final theme = Theme.of(context);
    final color = action.color ?? theme.colorScheme.primary;

    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: Icon(action.icon, size: 16),
      ),
      label: Text(
        action.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onPressed: () => _executeAction(context, action),
    );
  }

  Widget _buildGridButton(BuildContext context, CreateAction action) {
    final theme = Theme.of(context);
    final color = action.color ?? theme.colorScheme.primary;

    return OutlinedButton(
      onPressed: () => _executeAction(context, action),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: Icon(action.icon, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              action.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAction(BuildContext context, CreateAction action) async {
    final finalDateTime = DateTime(
      widget.targetDate.year,
      widget.targetDate.month,
      widget.targetDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    Navigator.of(context).pop();
    await action.run(context, finalDateTime);
  }
}
