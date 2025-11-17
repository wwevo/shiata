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
      appBar: AppBar(
        title: const Text('All Entries'),
      ),
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

          // Group entries for product/recipe children lookup
          final childrenByParent = <String, List<EntryRecord>>{};
          for (final entry in entries) {
            if (entry.sourceEntryId != null) {
              (childrenByParent[entry.sourceEntryId!] ??= []).add(entry);
            }
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final entry = entries[i];

              // Use factory to build consistent list items
              if (entry.widgetKind == 'product') {
                return EntryListItemFactory.buildProductListItem(
                  context: context,
                  ref: ref,
                  entry: entry,
                  children: childrenByParent[entry.id] ?? [],
                  config: EntryListItemConfig.fullDateTime,
                );
              } else if (entry.widgetKind == 'recipe') {
                return EntryListItemFactory.buildRecipeListItem(
                  context: context,
                  ref: ref,
                  entry: entry,
                  children: childrenByParent[entry.id] ?? [],
                  childrenByParent: childrenByParent,
                  registry: registry,
                  config: EntryListItemConfig.fullDateTime,
                );
              } else {
                return EntryListItemFactory.buildKindListItem(
                  context: context,
                  ref: ref,
                  entry: entry,
                  registry: registry,
                  config: EntryListItemConfig.fullDateTime,
                );
              }
            },
          );
        },
      ),
    );
  }
}
