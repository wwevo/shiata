import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/widgets/create_action.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../ux_config.dart';

class CreateActionSheetContent extends ConsumerStatefulWidget {
  const CreateActionSheetContent({
    super.key,
    required this.targetDate,
    this.items, // Optional - if null, will fetch from registry
  });

  final DateTime targetDate;
  final List<({WidgetKind kind, CreateAction action})>? items;

  @override
  ConsumerState<CreateActionSheetContent> createState() => _CreateActionSheetContentState();
}

class _CreateActionSheetContentState extends ConsumerState<CreateActionSheetContent> {
  late SectionLayout _layout;

  @override
  void initState() {
    super.initState();
    // Initialize from config
    final config = ref.read(uxConfigProvider);
    _layout = config.actionSheet.defaultLayout;
  }

  @override
  Widget build(BuildContext context) {
    // Use provided items, or fetch from registry if not provided
    final actionItems = widget.items ?? ref.read(widgetRegistryProvider).actionsForDate(context, widget.targetDate);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with layout toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add entry', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: Icon(_layout == SectionLayout.wrap ? Icons.grid_view : Icons.view_agenda),
                    onPressed: () => setState(() {
                      _layout = _layout == SectionLayout.wrap ? SectionLayout.grid : SectionLayout.wrap;
                    }),
                    tooltip: _layout == SectionLayout.wrap ? 'Switch to grid' : 'Switch to wrap',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Single unified section for all items
              _buildUnifiedSection(
                context: context,
                items: actionItems,
                layout: _layout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedSection({
    required BuildContext context,
    required List<({WidgetKind kind, CreateAction action})> items,
    required SectionLayout layout,
  }) {
    if (items.isEmpty) {
      return Text('No items available', style: Theme.of(context).textTheme.bodySmall);
    }

    return _buildItemList(
      context: context,
      items: items,
      layout: layout,
      chipBuilder: (item) => _buildChip(context, item),
    );
  }

  /// Builds either a Wrap or GridView based on layout setting
  Widget _buildItemList<T>({
    required BuildContext context,
    required List<T> items,
    required SectionLayout layout,
    required Widget Function(T) chipBuilder,
  }) {
    if (layout == SectionLayout.wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final item in items) chipBuilder(item)],
      );
    }

    // Grid layout
    return LayoutBuilder(
      builder: (ctx, cons) {
        final width = cons.maxWidth;
        final col = width >= 480 ? 4 : width >= 360 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: col,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) => chipBuilder(items[i]),
        );
      },
    );
  }

  /// Unified chip builder for all item types
  Widget _buildChip(BuildContext context, ({WidgetKind kind, CreateAction action}) item) {
    final color = item.action.color ?? item.kind.accentColor;

    if (_layout == SectionLayout.wrap) {
      // Wrap layout: use ActionChip
      return ActionChip(
        label: Text(item.action.label),
        avatar: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(item.action.icon, size: 16),
        ),
        onPressed: () async {
          Navigator.of(context).pop();
          await item.action.run(context, widget.targetDate);
        },
      );
    }

    // Grid layout: use OutlinedButton
    return OutlinedButton(
      onPressed: () async {
        Navigator.of(context).pop();
        await item.action.run(context, widget.targetDate);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: Icon(item.action.icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.action.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
