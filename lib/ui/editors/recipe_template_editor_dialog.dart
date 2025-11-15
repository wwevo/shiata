import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipes_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/editor_dialog_actions.dart';

class RecipeEditorDialog extends ConsumerStatefulWidget {
  const RecipeEditorDialog({super.key, required this.recipeId});
  final String recipeId;
  @override
  ConsumerState<RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends ConsumerState<RecipeEditorDialog> {
  // State variables
  List<RecipeComponentDef> _components = const [];
  bool _loading = true;
  bool _saving = false;
  String _recipeName = '';
  final Map<String, TextEditingController> _controllers = {};

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
      if (mounted) {
        setState(() {
          _recipeName = def?.name ?? widget.recipeId;
          _components = comps;
          _loading = false;
        });
      }
      // Initialize controllers for all components
      for (final c in comps) {
        if (c.type == RecipeComponentType.kind) {
          _controllers['kind_${c.compId}'] = TextEditingController(text: fmtDouble(c.amount ?? 0.0));
        } else {
          _controllers['product_${c.compId}'] = TextEditingController(text: (c.grams ?? 0).toString());
        }
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    setState(() => _saving = true);
    final repo = ref.read(recipesRepositoryProvider);
    if (repo == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    // Read values from controllers and update components
    final updatedComponents = <RecipeComponentDef>[];
    for (final c in _components) {
      if (c.type == RecipeComponentType.kind) {
        final ctrl = _controllers['kind_${c.compId}']!;
        final val = double.tryParse(ctrl.text.trim()) ?? c.amount ?? 0.0;
        updatedComponents.add(RecipeComponentDef.kind(
          recipeId: c.recipeId,
          compId: c.compId,
          amount: val,
        ));
      } else {
        final ctrl = _controllers['product_${c.compId}']!;
        final val = int.tryParse(ctrl.text.trim()) ?? c.grams ?? 0;
        updatedComponents.add(RecipeComponentDef.product(
          recipeId: c.recipeId,
          compId: c.compId,
          grams: val,
        ));
      }
    }
    await repo.setComponents(widget.recipeId, updatedComponents);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved recipe')));
    if (mounted) setState(() => _saving = false);
    if (closeAfter && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showAddMenu() async {
    final registry = ref.read(widgetRegistryProvider);
    final productsRepo = ref.read(productsRepositoryProvider);

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add component'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('kind'),
            child: const ListTile(
              leading: Icon(Icons.category_outlined),
              title: Text('Add kind'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('product'),
            child: const ListTile(
              leading: Icon(Icons.shopping_basket_outlined),
              title: Text('Add product'),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    switch (choice) {
      case 'kind':
        final picked = await showDialog<String?>(
          context: context,
          builder: (ctx) => _AddKindToRecipeDialog(registry: registry),
        );
        if (picked != null) {
          setState(() {
            // Remove if exists, then add new
            _components = [
              ..._components.where((c) => !(c.type == RecipeComponentType.kind && c.compId == picked)),
              RecipeComponentDef.kind(recipeId: widget.recipeId, compId: picked, amount: 0.0),
            ];
            // Create controller for new component
            _controllers['kind_$picked'] = TextEditingController(text: '0');
          });
        }
        break;
      case 'product':
        if (productsRepo == null) return;
        final picked = await showDialog<String?>(
          context: context,
          builder: (ctx) => _AddProductToRecipeDialog(productsRepo: productsRepo),
        );
        if (picked != null) {
          setState(() {
            // Remove if exists, then add new
            _components = [
              ..._components.where((c) => !(c.type == RecipeComponentType.product && c.compId == picked)),
              RecipeComponentDef.product(recipeId: widget.recipeId, compId: picked, grams: 100),
            ];
            // Create controller for new component
            _controllers['product_$picked'] = TextEditingController(text: '100');
          });
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);

    return AlertDialog(
      title: Text('Edit: ${_recipeName.isEmpty ? widget.recipeId : _recipeName}'),
      content: _loading
          ? const SizedBox(
        width: 500,
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      )
          : SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: _components.isEmpty
                  ? const Center(child: Text('No components yet'))
                  : ListView.separated(
                itemCount: _components.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = _components[i];
                  if (c.type == RecipeComponentType.kind) {
                    final kind = registry.byId(c.compId);
                    final ctrl = _controllers['kind_${c.compId}']!;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kind?.accentColor ?? Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        child: Icon(kind?.icon ?? Icons.circle, size: 18),
                      ),
                      title: Text(kind?.displayName ?? c.compId),
                      subtitle: Text('Unit: ${kind?.unit ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: '0',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                _components = _components.where((x) => !(x.type == RecipeComponentType.kind && x.compId == c.compId)).toList();
                              });
                              // Dispose controller
                              ctrl.dispose();
                              _controllers.remove('kind_${c.compId}');
                            },
                          ),
                        ],
                      ),
                    );
                  } else {
                    final ctrl = _controllers['product_${c.compId}']!;
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.shopping_basket, size: 18),
                      ),
                      title: Text(c.compId),
                      subtitle: const Text('Unit: g'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '100',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                _components = _components.where((x) => !(x.type == RecipeComponentType.product && x.compId == c.compId)).toList();
                              });
                              // Dispose controller
                              ctrl.dispose();
                              _controllers.remove('product_${c.compId}');
                            },
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _showAddMenu,
                icon: const Icon(Icons.add),
                label: const Text('Add component'),
              ),
            ),
          ],
        ),
      ),
      actions: editorDialogActions(
        context: context,
        onSave: ({required closeAfter}) => _save(context, closeAfter: closeAfter),
        isSaving: _saving,
      ),
    );
  }
}

class _AddKindToRecipeDialog extends StatefulWidget {
  const _AddKindToRecipeDialog({required this.registry});
  final WidgetRegistry registry;

  @override
  State<_AddKindToRecipeDialog> createState() => _AddKindToRecipeDialogState();
}

class _AddKindToRecipeDialogState extends State<_AddKindToRecipeDialog> {
  WidgetKind? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add kind'),
      content: DropdownButtonFormField<WidgetKind>(
        value: _selected,
        items: [
          for (final k in widget.registry.kinds)
            DropdownMenuItem(value: k, child: Text(k.displayName)),
        ],
        onChanged: (v) => setState(() => _selected = v),
        decoration: const InputDecoration(labelText: 'Select kind'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final k = _selected;
            if (k == null) return;
            Navigator.of(context).pop(k.id);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AddProductToRecipeDialog extends StatefulWidget {
  const _AddProductToRecipeDialog({required this.productsRepo});
  final ProductsRepository productsRepo;

  @override
  State<_AddProductToRecipeDialog> createState() => _AddProductToRecipeDialogState();
}

class _AddProductToRecipeDialogState extends State<_AddProductToRecipeDialog> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductDef>>(
      future: widget.productsRepo.listProducts(),
      builder: (ctx, snap) {
        final products = snap.data ?? const <ProductDef>[];
        return AlertDialog(
          title: const Text('Add product'),
          content: DropdownButtonFormField<String>(
            value: _selectedId,
            items: [
              for (final p in products)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _selectedId = v),
            decoration: const InputDecoration(labelText: 'Select product'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final id = _selectedId;
                if (id == null) return;
                Navigator.of(context).pop(id);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}