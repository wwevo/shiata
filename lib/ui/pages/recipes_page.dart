import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import '../widgets/add_floating_action_button.dart';
import '../widgets/entry_list_item_factory.dart';

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesListProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final hierarchy = ref.watch(managementHierarchyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
      ),
      floatingActionButton: const AppAddFloatingActionButton(
        pageId: 'recipes',
      ),
      body: recipesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No recipes yet'));
          }
          return ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (ctx, i) {
              return EntryListItemFactory.buildEntry(
                context: context,
                ref: ref,
                entry: list[i],
                childrenByParent: hierarchy,
                registry: registry,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
