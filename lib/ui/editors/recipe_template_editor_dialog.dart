import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipe_hierarchy_service.dart';
import '../../data/repo/recipes_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/editor_dialog_shell.dart';
import '../widgets/validation_rules.dart';

class RecipeEditorDialog extends ConsumerStatefulWidget {
  const RecipeEditorDialog({
    super.key,
    this.existing, // null for create, non-null for edit
  });

  final RecipeDef? existing;

  @override
  ConsumerState<RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends ConsumerState<RecipeEditorDialog>
    with EditorDialogShell {
  // State variables
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _iconController;
  late final TextEditingController _colorController;
  List<RecipeComponentDef> _components = const [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    loading = true;
    final e = widget.existing;
    _idController = TextEditingController(text: e?.id ?? generateRandomId('recipe_'));
    _nameController = TextEditingController(text: e?.name ?? '');
    _iconController = TextEditingController(text: e?.icon ?? '');
    _colorController = TextEditingController(
      text: e?.color?.toString() ?? '',
    );
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(recipesRepositoryProvider);
    if (repo != null && widget.existing != null) {
      // Edit mode: load components for existing recipe
      final comps = await repo.getComponents(widget.existing!.id);
      if (mounted) {
        setState(() {
          _components = comps;
          loading = false;
        });
      }
      // Initialize controllers for all components
      for (final c in comps) {
        if (c.type == RecipeComponentType.kind) {
          _controllers['kind_${c.compId}'] = TextEditingController(
            text: fmtDouble(c.amount ?? 0.0),
          );
        } else {
          _controllers['product_${c.compId}'] = TextEditingController(
            text: (c.grams ?? 0).toString(),
          );
        }
      }
    } else {
      // Create mode: no components to load
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final repo = ref.read(recipesRepositoryProvider);
        if (repo == null) return;

        // Get id and name from controllers
        final recipeId = _idController.text.trim();
        final recipeName = _nameController.text.trim();

        // Upsert recipe (create or update)
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        final isEdit = widget.existing != null;
        await repo.upsertRecipe(
          RecipeDef(
            id: recipeId,
            name: recipeName,
            createdAt: widget.existing?.createdAt ?? now,
            updatedAt: now,
            isActive: widget.existing?.isActive ?? true,
            icon: _iconController.text.trim().isEmpty
                ? null
                : _iconController.text.trim(),
            color: parseInt(_colorController.text),
            isProtected: widget.existing?.isProtected ?? false,
          ),
          oldId: widget.existing?.id,
        );

        // Read values from controllers and update components
        final updatedComponents = <RecipeComponentDef>[];
        for (final c in _components) {
          if (c.type == RecipeComponentType.kind) {
            final ctrl = _controllers['kind_${c.compId}']!;
            final val = parseDouble(ctrl.text) ?? c.amount ?? 0.0;
            updatedComponents.add(
              RecipeComponentDef.kind(
                recipeId: recipeId,
                compId: c.compId,
                amount: val,
              ),
            );
          } else {
            final ctrl = _controllers['product_${c.compId}']!;
            final val = parseInt(ctrl.text) ?? c.grams ?? 0;
            updatedComponents.add(
              RecipeComponentDef.product(
                recipeId: recipeId,
                compId: c.compId,
                grams: val,
              ),
            );
          }
        }
        await repo.setComponents(recipeId, updatedComponents);

        if (!context.mounted) return;

        // Ask to propagate to non-static instances if they exist
        final svc = ref.read(recipeHierarchyServiceProvider);
        bool doProp = false;
        if (svc != null && await svc.hasNonStaticEntriesForRecipe(recipeId)) {
          if (!mounted) return;
          doProp = (await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirm propagation'),
              content: const Text(
                'Apply these changes to all non-static recipe instances?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Yes, update'),
                ),
              ],
            ),
          )) ?? false;
        }

        if (doProp == true && svc != null) {
          await svc.propagateTemplateChange(recipeId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Updated existing recipe instances')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEdit ? 'Updated recipe-template' : 'Created recipe-template'),
              ),
            );
          }
        }
      },
    );
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

    if (choice == null || !mounted) return;

    switch (choice) {
      case 'kind':
        final picked = await showDialog<String?>(
          context: context,
          builder: (ctx) => _AddKindToRecipeDialog(registry: registry),
        );
        if (picked != null) {
          setState(() {
            // Remove if exists, then add new
            final recipeId = widget.existing?.id ?? _idController.text.trim();
            _components = [
              ..._components.where(
                (c) =>
                    !(c.type == RecipeComponentType.kind && c.compId == picked),
              ),
              RecipeComponentDef.kind(
                recipeId: recipeId,
                compId: picked,
                amount: 0.0,
              ),
            ];
            // Create controller for new component
            _controllers['kind_$picked'] = TextEditingController(text: '0');
          });
        }
        break;
      case 'product':
        if (productsRepo == null) return;
        if (!mounted) return;
        final picked = await showDialog<String?>(
          context: context,
          builder: (ctx) =>
              _AddProductToRecipeDialog(productsRepo: productsRepo),
        );
        if (picked != null) {
          setState(() {
            // Remove if exists, then add new
            final recipeId = widget.existing?.id ?? _idController.text.trim();
            _components = [
              ..._components.where(
                (c) =>
                    !(c.type == RecipeComponentType.product &&
                        c.compId == picked),
              ),
              RecipeComponentDef.product(
                recipeId: recipeId,
                compId: picked,
                grams: 100,
              ),
            ];
            // Create controller for new component
            _controllers['product_$picked'] = TextEditingController(
              text: '100',
            );
          });
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);
    final isEdit = widget.existing != null;

    return buildShell(
      context: context,
      title: isEdit ? 'Edit recipe' : 'Add recipe',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        children: [
          // Id and Name fields
          TextFormField(
            controller: _idController,
            enabled: !(widget.existing?.isProtected ?? false),
            decoration: const InputDecoration(
              labelText: 'Id (stable, e.g., breakfast_smoothie)',
            ),
            validator: (v) => ValidationRules.required(v, 'Id'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name (display)'),
            validator: (v) => ValidationRules.required(v, 'Name'),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _components.isEmpty
              ? const SizedBox(
                height: 100,
                child: Center(child: Text('No components yet')),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _components.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = _components[i];
                  if (c.type == RecipeComponentType.kind) {
                    final kind = registry.byId(c.compId);
                    final ctrl = _controllers['kind_${c.compId}']!;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            kind?.accentColor ??
                            Theme.of(context).colorScheme.primary,
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
                            child: TextFormField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                                isDense: true,
                              ),
                              validator: ValidationRules.nonNegativeAmount,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                _components = _components
                                    .where(
                                      (x) =>
                                          !(x.type == RecipeComponentType.kind &&
                                              x.compId == c.compId),
                                    )
                                    .toList();
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
                            child: TextFormField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '100',
                                isDense: true,
                              ),
                              validator: ValidationRules.positiveGrams,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                _components = _components
                                    .where(
                                      (x) =>
                                          !(x.type ==
                                                  RecipeComponentType.product &&
                                              x.compId == c.compId),
                                    )
                                    .toList();
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
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: loading ? null : _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('Add component'),
            ),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Presentation'),
            children: [
              TextFormField(
                controller: _iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon name (Material glyph, optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _colorController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Color ARGB int (e.g., 4283657726)',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return parseInt(v) == null ? 'Must be an integer' : null;
                },
              ),
            ],
          ),
        ],
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
      content: DropdownButton<WidgetKind>(
        value: _selected,
        hint: const Text('Select kind'),
        isExpanded: true,
        items: [
          for (final k in widget.registry.kinds)
            DropdownMenuItem(value: k, child: Text(k.displayName)),
        ],
        onChanged: (v) => setState(() => _selected = v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
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
  State<_AddProductToRecipeDialog> createState() =>
      _AddProductToRecipeDialogState();
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
          content: DropdownButton<String>(
            value: _selectedId,
            hint: const Text('Select product'),
            isExpanded: true,
            items: [
              for (final p in products)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _selectedId = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
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
