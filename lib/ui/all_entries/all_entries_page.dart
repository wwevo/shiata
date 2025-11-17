import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import '../widgets/entry_list_item_factory.dart';

/// Page that displays all entries with search filtering.
class AllEntriesPage extends ConsumerWidget {
  const AllEntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchService = ref.watch(searchServiceProvider);
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    if (searchService == null || repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Entries')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All Entries')),
      body: StreamBuilder<List<EntryRecord>>(
        stream: searchService.searchAllEntries(searchQuery),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? <EntryRecord>[];

          if (searchQuery.trim().isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Type in the search field to find entries'),
              ),
            );
          }

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No entries found for "$searchQuery"',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          // Group entries for recursive rendering
          final childrenByParent = <String, List<EntryRecord>>{};
          for (final entry in entries) {
            if (entry.sourceEntryId != null) {
              (childrenByParent[entry.sourceEntryId!] ??= []).add(entry);
            }
          }

          // Only show top-level entries (children are rendered recursively)
          final topLevelEntries = entries
              .where((e) => e.sourceEntryId == null)
              .toList();

          // Group by date for better organization
          final entriesByDate = <String, List<EntryRecord>>{};
          for (final entry in topLevelEntries) {
            final local = DateTime.fromMillisecondsSinceEpoch(
              entry.targetAt,
              isUtc: true,
            ).toLocal();
            final dateKey =
                '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
            (entriesByDate[dateKey] ??= []).add(entry);
          }

          // Sort dates descending (most recent first)
          final sortedDates = entriesByDate.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (ctx, dateIndex) {
              final dateKey = sortedDates[dateIndex];
              final dateEntries = entriesByDate[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      dateKey,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  // Entries for this date
                  ...dateEntries.map(
                    (entry) => EntryListItemFactory.buildEntry(
                      context: context,
                      ref: ref,
                      entry: entry,
                      childrenByParent: childrenByParent,
                      registry: registry,
                      config: EntryListItemConfig.fullDateTime,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
