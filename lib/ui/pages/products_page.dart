import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/widgets/registry.dart';
import '../editors/product_template_editor_dialog.dart';
import '../main_screen_providers.dart';
import '../widgets/entry_list_item_factory.dart';

class ProductTemplatesPage extends ConsumerWidget {
  const ProductTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsListProvider);
    final repo = ref.watch(productsRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final hierarchy = ref.watch(managementHierarchyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add product',
            onPressed: repo == null
                ? null
                : () async {
                    showDialog(
                      context: context,
                      builder: (_) => const ProductTemplateEditorDialog(
                        existing: null, // Create mode
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No products yet'));
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
