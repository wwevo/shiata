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

        // Group entries for recursive rendering
        final childrenByParent = <String, List<EntryRecord>>{};
        for (final entry in results) {
          if (entry.sourceEntryId != null) {
            (childrenByParent[entry.sourceEntryId!] ??= []).add(entry);
          }
        }

        // Only show top-level entries (children are rendered recursively)
        final topLevelEntries = results.where((e) => e.sourceEntryId == null).toList();

        return ListView.builder(
          controller: controller,
          itemCount: topLevelEntries.length,
          itemBuilder: (ctx, i) {
            return EntryListItemFactory.buildEntry(
              context: context,
              ref: ref,
              entry: topLevelEntries[i],
              childrenByParent: childrenByParent,
              registry: registry,
              config: EntryListItemConfig.fullDateTime,
            );
          },
        );
      },
    );
  }
}
