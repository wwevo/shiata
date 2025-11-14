import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/import_export_service.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/products_repository.dart';
import '../editors/product_template_editor_dialog.dart';

Future<void> _exportJsonProducts(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(importExportServiceProvider);
  if (svc == null) return;
  try {
    final bundle = await svc.exportBundle();
    final encoder = const JsonEncoder.withIndent('  ');
    final text = encoder.convert(bundle);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export (JSON)'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
              }
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

Future<void> _importJsonProducts(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(importExportServiceProvider);
  if (svc == null) return;
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import (JSON)'),
      content: SizedBox(
        width: 600,
        child: TextField(
          controller: controller,
          maxLines: 16,
          decoration: const InputDecoration(hintText: '{"version":1, ...}'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final result = await svc.importBundle(controller.text);
    if (!context.mounted) return;
    final msg = 'Imported: ${result.kindsUpserted} kinds, ${result.productsUpserted} products, ${result.componentsWritten} components${result.warnings.isEmpty ? '' : '\nWarnings: ${result.warnings.length}'}';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import result'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Text(result.warnings.isEmpty ? msg : ('$msg\n\n${result.warnings.join('\n')}')),
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

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
              if (!context.mounted) return;
              final name = await _askForName(context, suggestion: _titleCase(id.replaceAll('_', ' ')));
              if (name == null || name.trim().isEmpty) return;
              final now = DateTime.now().toUtc().millisecondsSinceEpoch;
              await repo.upsertProduct(ProductDef(id: id.trim(), name: name.trim(), createdAt: now, updatedAt: now));
              if (context.mounted) {
/*
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductTemplateEditorPage(productId: id.trim())),
                );
*/
                showDialog(
                  context: context,
                  builder: (_) => ProductTemplateEditorDialog(productId: id.trim()),
                );
              }
            },
            icon: const Icon(Icons.add),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'export':
                  await _exportJsonProducts(context, ref);
                  break;
                case 'import':
                  await _importJsonProducts(context, ref);
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'export', child: Text('Export (JSON)')),
              PopupMenuItem(value: 'import', child: Text('Import (JSON)')),
            ],
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
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final p = list[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.shopping_basket, color: Colors.white),
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
