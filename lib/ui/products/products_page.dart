import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/products_repository.dart';
import '../editors/product_template_editor_dialog.dart';
import '../widgets/icon_resolver.dart';

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
            onPressed: repo == null
                ? null
                : () async {
                    final created = await _askForIdAndName(context);
                    if (created == null) return;
                    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
                    await repo.upsertProduct(ProductDef(id: created.key, name: created.value, createdAt: now, updatedAt: now));
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => ProductTemplateEditorDialog(productId: created.key),
                      );
                    }
                  },
            icon: const Icon(Icons.add),
          ),
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
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final p = list[i];
                    final icon = resolveIcon(p.icon, Icons.shopping_basket);
                    final color = p.color != null ? Color(p.color!) : Colors.purple;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  builder: (_) => ProductTemplateEditorDialog(productId: p.id),
                                );
                              },
                            ),
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

  Future<MapEntry<String, String>?> _askForIdAndName(BuildContext context) async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('New product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'Id (stable, e.g., egg)')),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (display)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
            ],
          ),
        ) ??
        false;
    if (!ok) return null;
    final id = idCtrl.text.trim();
    final name = nameCtrl.text.trim();
    if (id.isEmpty || name.isEmpty) return null;
    return MapEntry(id, name);
  }
}
