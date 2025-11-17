import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import 'action_sheet_helpers.dart';
import 'entry_list_item_factory.dart';

class DayDetailsPanel extends ConsumerWidget {
  const DayDetailsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final repo = ref.watch(entriesRepositoryProvider);
    final searchService = ref.watch(searchServiceProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    if (selected == null || repo == null || searchService == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use context-aware search: search only the selected day
    final entriesStream = searchService.searchEntriesForDay(searchQuery, selected);

    return StreamBuilder<List<EntryRecord>>(
      stream: entriesStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <EntryRecord>[];

        // Parents/standalone are entries without a source; children have a source_entry_id
        final entries = all.where((e) => e.sourceEntryId == null).toList();
        final childrenByParent = <String, List<EntryRecord>>{};
        for (final c in all) {
          if (c.sourceEntryId != null) {
            (childrenByParent[c.sourceEntryId!] ??= []).add(c);
          }
        }

        if (entries.isEmpty) {
          // Empty state: show date and a single Add button that opens the Create Action Sheet
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (ctx) {
                    final handed = ref.watch(handednessProvider);
                    final dateText = Expanded(
                      child: Text(
                        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                    final addBtn = IconButton(
                      tooltip: 'Add',
                      onPressed: () => showCreateActionSheet(context, ref, selected),
                      icon: const Icon(Icons.add_circle_outline),
                    );
                    return Row(
                      children: handed == Handedness.left
                          ? [addBtn, const SizedBox(width: 8), dateText]
                          : [dateText, addBtn],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'No entries for this day yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Builder(
                builder: (ctx) {
                  final handed = ref.watch(handednessProvider);
                  final dateText = Expanded(
                    child: Text(
                      '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                  final addBtn = IconButton(
                    tooltip: 'Add',
                    onPressed: () => showCreateActionSheet(context, ref, selected),
                    icon: const Icon(Icons.add_circle_outline),
                  );
                  return Row(
                    children: handed == Handedness.left
                        ? [addBtn, const SizedBox(width: 8), dateText]
                        : [dateText, addBtn],
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (ctx, i) {
                  return EntryListItemFactory.buildEntry(
                    context: context,
                    ref: ref,
                    entry: entries[i],
                    childrenByParent: childrenByParent,
                    registry: registry,
                    config: EntryListItemConfig.dayDetails,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
