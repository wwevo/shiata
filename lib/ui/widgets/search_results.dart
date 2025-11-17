import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import 'entry_list_item_factory.dart';

class SearchResults extends ConsumerWidget {
  const SearchResults({super.key, required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final q = ref.watch(searchQueryProvider);

    if (repo == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<EntryRecord>>(
      stream: repo.watchSearch(q),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const <EntryRecord>[];

        if (q.trim().isEmpty) {
          return const Center(child: Text('Type to search'));
        }

        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No results for "$q"',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        // Group entries for product/recipe children lookup
        final childrenByParent = <String, List<EntryRecord>>{};
        for (final entry in results) {
          if (entry.sourceEntryId != null) {
            (childrenByParent[entry.sourceEntryId!] ??= []).add(entry);
          }
        }

        return ListView.builder(
          controller: controller,
          itemCount: results.length,
          itemBuilder: (ctx, i) {
            final entry = results[i];

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
    );
  }
}
