import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/products_repository.dart';
import '../editors/product_template_editor_dialog.dart';
import '../main_screen_providers.dart';
import '../widgets/icon_resolver.dart';

class ProductTemplatesPage extends ConsumerWidget {
  const ProductTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchService = ref.watch(searchServiceProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final repo = ref.watch(productsRepositoryProvider);

    // Use search service for filtering
    final productsStream = searchService?.searchProducts(searchQuery);

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
      body: productsStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<ProductDef>>(
              stream: productsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snapshot.data ?? const <ProductDef>[];

                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      searchQuery.trim().isEmpty
                          ? 'No products yet'
                          : 'No products found for "$searchQuery"',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final p = list[i];
                    final icon = resolveIcon(p.icon, Icons.shopping_basket);
                    final color = p.color != null
                        ? Color(p.color!)
                        : Colors.purple;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          child: Icon(icon, color: Colors.white),
                        ),
                        title: Text(p.name),
                        subtitle: Text(p.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (_) => ProductTemplateEditorDialog(
                                    existing: p,
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteProduct(context, ref, p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _deleteProduct(
    BuildContext context,
    WidgetRef ref,
    ProductDef product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text(
          'Instances will be converted: parent rows removed, kind entries kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final svc = ref.read(productServiceProvider);
      await svc?.deleteProductTemplate(product.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted ${product.name}; instances converted')),
      );
    }
  }

}
