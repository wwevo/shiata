import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/product_service.dart';
import 'product_template_editor.dart';

class ProductTemplatesPage extends ConsumerWidget {
  const ProductTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(productsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add product',
            onPressed: () async {
              if (repo == null) return;
              final id = await _askForId(context);
              if (id == null || id.trim().isEmpty) return;
              final name = await _askForName(context, suggestion: _titleCase(id.replaceAll('_', ' ')));
              if (name == null || name.trim().isEmpty) return;
              final now = DateTime.now().toUtc().millisecondsSinceEpoch;
              await repo.upsertProduct(ProductDef(id: id.trim(), name: name.trim(), createdAt: now, updatedAt: now));
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductTemplateEditorPage(productId: id.trim())),
                );
              }
            },
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: repo == null
          ? const Center(child: Text('Repository not ready'))
          : StreamBuilder<List<ProductDef>>(
              stream: repo.watchProducts(),
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <ProductDef>[];
                if (list.isEmpty) {
                  return const Center(child: Text('No products yet'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = list[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete product?'),
                                  content: const Text('Instances will be converted: parent rows removed, nutrient entries kept.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final svc = ref.read(productServiceProvider);
                                await svc?.deleteProductTemplate(p.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Deleted ${p.name}; instances converted')),
                                  );
                                }
                              }
                            },
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProductTemplateEditorPage(productId: p.id)),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  static Future<String?> _askForId(BuildContext context) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New product id'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'e.g., egg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
  }

  static Future<String?> _askForName(BuildContext context, {String? suggestion}) async {
    final c = TextEditingController(text: suggestion ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product name'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'e.g., Egg'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
  }

  static String _titleCase(String s) {
    return s.split(' ').map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1))).join(' ');
  }
}
