// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/widgets/registry.dart';
import '../domain/widgets/widget_kind.dart';
import 'main_screen.dart' show selectedDayProvider; // reuse selected day

/// Middle section list that is dynamically generated from the WidgetRegistry.
/// Each card represents a widget kind and triggers that kind's primary action
/// (highest priority) for the selected day (defaults to today).
class _MainActionsList extends ConsumerWidget {
  const _MainActionsList({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(widgetRegistryProvider);
    final kinds = registry.all;

    // Determine target date (day) used by actions: selected day or today.
    final selected = ref.watch(selectedDayProvider);
    final now = DateTime.now();
    final targetDay = selected != null
        ? DateTime(selected.year, selected.month, selected.day)
        : DateTime(now.year, now.month, now.day);

    if (kinds.isEmpty) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.only(top: 16, bottom: 80),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No widgets registered',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
          )
        ],
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      itemCount: kinds.length,
      itemBuilder: (ctx, index) {
        final WidgetKind kind = kinds[index];
        // Get actions and pick the highest priority one to represent this kind.
        final actions = kind.createActions(context, targetDay);
        actions.sort((a, b) => b.priority.compareTo(a.priority));
        final primary = actions.isNotEmpty ? actions.first : null;

        final Color color = kind.accentColor;
        final IconData icon = kind.icon;
        final String title = kind.displayName;
        final String subtitle = primary?.label ?? 'Unavailable';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              enabled: primary != null,
              leading: CircleAvatar(
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: Icon(icon, color: Colors.white),
              ),
              title: Text(title),
              subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
              onTap: primary == null
                  ? null
                  : () async {
                      // Run the selected action. It will handle navigation and
                      // will compute the current time component if needed.
                      await primary.run(context, targetDay);
                    },
            ),
          ),
        );
      },
    );
  }
}
