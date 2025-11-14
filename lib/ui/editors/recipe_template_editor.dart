
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipes_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';

class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({super.key, required this.recipeId});
  final String recipeId;
  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  List<RecipeComponentDef> _components = const [];
  bool _loading = true;
  String _recipeName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(recipesRepositoryProvider);
    if (repo != null) {
      final def = await repo.getRecipe(widget.recipeId);
      final comps = await repo.getComponents(widget.recipeId);
      setState(() {
        _recipeName = def?.name ?? widget.recipeId;
        _components = comps;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final repo = ref.read(recipesRepositoryProvider);
    if (repo == null) return;
    await repo.setComponents(widget.recipeId, _components);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved recipe')));
  }

  String _fmtDouble(double v) {
    final s = v.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+\$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);
    final productsRepo = ref.watch(productsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${_recipeName.isEmpty ? widget.recipeId : _recipeName}'),
        actions: [
          IconButton(onPressed: _loading ? null : _save, icon: const Icon(Icons.check), tooltip: 'Save'),
        ],
      ),
      floatingActionButton: PopupMenuButton<String>(
        tooltip: 'Add component',
        onSelected: (value) async {
          switch (value) {
            case 'kind':
              final picked = await showDialog<(String, double)?>(
                context: context,
                builder: (ctx) => _AddKindToRecipeDialog(registry: registry),
              );
              if (picked != null) {
                setState(() {
                  _components = [
                    ..._components.where((c) => !(c.type == RecipeComponentType.kind && c.compId == picked.$1)),
                    RecipeComponentDef.kind(recipeId: widget.recipeId, compId: picked.$1, amount: picked.$2),
                  ];
                });
              }
              break;
            case 'product':
              if (productsRepo == null) return;
              final picked = await showDialog<(String, int)?>(
                context: context,
                builder: (ctx) => _AddProductToRecipeDialog(productsRepo: productsRepo),
              );
              if (picked != null) {
                setState(() {
                  _components = [
                    ..._components.where((c) => !(c.type == RecipeComponentType.product && c.compId == picked.$1)),
                    RecipeComponentDef.product(recipeId: widget.recipeId, compId: picked.$1, grams: picked.$2),
                  ];
                });
              }
              break;
          }
        },
        itemBuilder: (ctx) => const [
          PopupMenuItem(value: 'kind', child: ListTile(leading: Icon(Icons.category_outlined), title: Text('Add kind'))),
          PopupMenuItem(value: 'product', child: ListTile(leading: Icon(Icons.shopping_basket_outlined), title: Text('Add product'))),
        ],
        child: const FloatingActionButton.extended(onPressed: null, label: Text('Add'), icon: Icon(Icons.add)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _components.isEmpty
          ? const Center(child: Text('No components yet'))
          : ListView.separated(
        itemCount: _components.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final c = _components[i];
          if (c.type == RecipeComponentType.kind) {
            final kind = registry.byId(c.compId);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: kind?.accentColor ?? Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                child: Icon(kind?.icon ?? Icons.circle, size: 18),
              ),
              title: Text(kind?.displayName ?? c.compId),
              subtitle: Text('Amount: ${_fmtDouble(c.amount ?? 0.0)} ${kind?.unit ?? ''}'),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _components = [
                  ..._components.where((x) => !(x.type == RecipeComponentType.kind && x.compId == c.compId)),
                ]),
              ),
              onTap: () async {
                final v = await _askForDouble(context, 'Amount (${kind?.unit ?? ''})', c.amount ?? 0.0);
                if (v != null) {
                  setState(() {
                    _components = [
                      for (final x in _components)
                        if (x.type == RecipeComponentType.kind && x.compId == c.compId)
                          RecipeComponentDef.kind(recipeId: x.recipeId, compId: x.compId, amount: v)
                        else
                          x,
                    ];
                  });
                }
              },
            );
          } else {
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                child: Icon(Icons.shopping_basket, size: 18),
              ),
              title: Text(c.compId),
              subtitle: Text('Grams: ${c.grams ?? 0} g'),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _components = [
                  ..._components.where((x) => !(x.type == RecipeComponentType.product && x.compId == c.compId)),
                ]),
              ),
              onTap: () async {
                final v = await _askForInt(context, 'Grams', c.grams ?? 0);
                if (v != null) {
                  setState(() {
                    _components = [
                      for (final x in _components)
                        if (x.type == RecipeComponentType.product && x.compId == c.compId)
                          RecipeComponentDef.product(recipeId: x.recipeId, compId: x.compId, grams: v)
                        else
                          x,
                    ];
                  });
                }
              },
            );
          }
        },
      ),
    );
  }

  Future<double?> _askForDouble(BuildContext context, String title, double current) async {
    final c = TextEditingController(text: _fmtDouble(current));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(hintText: 'number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text.trim());
              if (v == null || v < 0) return;
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<int?> _askForInt(BuildContext context, String title, int current) async {
    final c = TextEditingController(text: current.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'integer'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(c.text.trim());
              if (v == null || v < 0) return;
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _AddKindToRecipeDialog extends StatelessWidget {
  const _AddKindToRecipeDialog({required this.registry});
  final WidgetRegistry registry;
  @override
  Widget build(BuildContext context) {
    final kinds = registry.kinds;
    WidgetKind? selected;
    final amountCtrl = TextEditingController(text: '0');
    return StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Add kind'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<WidgetKind>(
              items: [for (final k in kinds) DropdownMenuItem(value: k, child: Text(k.displayName))],
              onChanged: (v) => setState(() => selected = v),
              decoration: const InputDecoration(labelText: 'Kind'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Amount (number)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final k = selected;
              final v = double.tryParse(amountCtrl.text.trim());
              if (k == null || v == null || v < 0) return;
              Navigator.of(context).pop((k.id, v));
            },
            child: const Text('Add'),
          ),
        ],
      );
    });
  }
}

class _AddProductToRecipeDialog extends StatelessWidget {
  const _AddProductToRecipeDialog({required this.productsRepo});
  final ProductsRepository productsRepo;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: productsRepo.listProducts(),
      builder: (ctx, snap) {
        final products = snap.data ?? const <ProductDef>[];
        String? selectedId;
        final gramsCtrl = TextEditingController(text: '100');
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  items: [for (final p in products) DropdownMenuItem(value: p.id, child: Text(p.name))],
                  onChanged: (v) => setState(() => selectedId = v),
                  decoration: const InputDecoration(labelText: 'Product'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gramsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Grams (integer)'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final id = selectedId;
                  final g = int.tryParse(gramsCtrl.text.trim());
                  if (id == null || g == null || g <= 0) return;
                  Navigator.of(context).pop((id, g));
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }
}
