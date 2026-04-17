import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipe_hierarchy_service.dart';
import '../../data/repo/recipes_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/add_component_menu.dart';
import '../widgets/add_kind_dialog.dart';
import '../widgets/add_product_dialog.dart';
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

    // Step 1: Ask what type of component to add
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => const AddComponentMenu(
        enabledTypes: {'kind', 'product'}, // Can add 'recipe' when needed
      ),
    );

    if (type == null || !mounted) return;

    // Step 2: Show the appropriate picker based on type
    switch (type) {
      case 'kind':
        final kind = await showDialog<WidgetKind?>(
          context: context,
          builder: (ctx) => AddKindDialog(
            kinds: registry.kinds.toList(),
          ),
        );

        if (kind != null) {
          setState(() {
            // Remove if exists, then add new
            final recipeId = widget.existing?.id ?? _idController.text.trim();
            _components = [
              ..._components.where(
                    (c) =>
                !(c.type == RecipeComponentType.kind && c.compId == kind.id),
              ),
              RecipeComponentDef.kind(
                recipeId: recipeId,
                compId: kind.id,
                amount: 0.0,
              ),
            ];
            // Create controller for new component
            _controllers['kind_${kind.id}'] = TextEditingController(text: '0');
          });
        }
        break;

      case 'product':
        if (productsRepo == null) return;

        final products = await productsRepo.listProducts();
        if (!mounted) return;

        final product = await showDialog<ProductDef?>(
          context: context,
          builder: (ctx) => AddProductDialog(products: products),
        );

        if (product != null) {
          setState(() {
            // Remove if exists, then add new
            final recipeId = widget.existing?.id ?? _idController.text.trim();
            _components = [
              ..._components.where(
                    (c) =>
                !(c.type == RecipeComponentType.product &&
                    c.compId == product.id),
              ),
              RecipeComponentDef.product(
                recipeId: recipeId,
                compId: product.id,
                grams: 100,
              ),
            ];
            // Create controller for new component
            _controllers['product_${product.id}'] = TextEditingController(
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
