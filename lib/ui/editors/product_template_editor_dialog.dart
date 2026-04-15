// add/edit product template
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/products_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/add_kind_dialog.dart';
import '../widgets/editor_dialog_shell.dart';
import '../widgets/validation_rules.dart';

class ProductTemplateEditorDialog extends ConsumerStatefulWidget {
  const ProductTemplateEditorDialog({
    super.key,
    this.existing, // null for create, non-null for edit
  });

  final ProductDef? existing;

  @override
  ConsumerState<ProductTemplateEditorDialog> createState() =>
      _ProductTemplateEditorDialogState();
}

class _ProductTemplateEditorDialogState
    extends ConsumerState<ProductTemplateEditorDialog> with EditorDialogShell {
  // State variables
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _iconController;
  late final TextEditingController _colorController;
  List<ProductComponent> _components = const [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    loading = true;
    final e = widget.existing;
    _idController = TextEditingController(text: e?.id ?? generateRandomId('product_'));
    _nameController = TextEditingController(text: e?.name ?? '');
    _iconController = TextEditingController(text: e?.icon ?? '');
    _colorController = TextEditingController(
      text: e?.color?.toString() ?? '',
    );
    _load();
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

  Future<void> _load() async {
    final repo = ref.read(productsRepositoryProvider);
    if (repo != null && widget.existing != null) {
      // Edit mode: load components for existing product
      final comps = await repo.getComponents(widget.existing!.id);
      if (mounted) {
        setState(() {
          _components = comps;
          loading = false;
        });
        // Initialize controllers for each component
        for (final c in comps) {
          _controllers[c.kindId] = TextEditingController(
            text: fmtDouble(c.amountPerGram),
          );
        }
      }
    } else {
      // Create mode: no components to load
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final repo = ref.read(productsRepositoryProvider);
        final svc = ref.read(productServiceProvider);
        if (repo == null) return;

        // Get id and name from controllers
        final productId = _idController.text.trim();
        final productName = _nameController.text.trim();

        // Upsert product (create or update)
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        final isEdit = widget.existing != null;
        await repo.upsertProduct(
          ProductDef(
            id: productId,
            name: productName,
            createdAt: widget.existing?.createdAt ?? now,
            updatedAt: now,
            isActive: widget.existing?.isActive ?? true,
            icon: _iconController.text.trim().isEmpty
                ? null
                : _iconController.text.trim(),
            color: parseInt(_colorController.text),
            isProtected: widget.existing?.isProtected ?? false,
          ),
        );

        // Read values from controllers and update components
        final updatedComponents = <ProductComponent>[];
        for (final c in _components) {
          final ctrl = _controllers[c.kindId];
          final amount = parseDouble(ctrl?.text) ?? 0.0;
          updatedComponents.add(
            ProductComponent(
              productId: productId,
              kindId: c.kindId,
              amountPerGram: amount,
            ),
          );
        }
        await repo.setComponents(productId, updatedComponents);

        if (!context.mounted) return;

        // Ask to propagate to non-static instances if they exist
        bool doProp = false;
        if (svc != null && await svc.hasNonStaticEntriesForProduct(productId)) {
          if (!mounted) return;
          doProp = (await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirm propagation'),
              content: const Text(
                'Apply these changes to all non-static entries for this product?',
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
          await svc.updateAllEntriesForProductToCurrentFormula(productId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Updated existing entries')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEdit ? 'Updated product-template' : 'Created product-template'),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _addComponent() async {
    final registry = ref.read(widgetRegistryProvider);
    final kinds = registry.kinds.toList();
    final picked = await showDialog<WidgetKind?>(
      context: context,
      builder: (ctx) => AddKindDialog(kinds: kinds),
    );
    if (picked == null) return;
    setState(() {
      // Remove if already exists
      _components = [..._components.where((c) => c.kindId != picked.id)];
      // Add new component with initial value 0
      final productId = widget.existing?.id ?? _idController.text.trim();
      _components = [
        ..._components,
        ProductComponent(
          productId: productId,
          kindId: picked.id,
          amountPerGram: 0.0,
        ),
      ];
      // Create controller for the new component
      _controllers[picked.id] = TextEditingController(text: '0');
    });
  }

  void _removeAt(int index) {
    setState(() {
      final c = _components[index];
      // Dispose and remove controller
      _controllers[c.kindId]?.dispose();
      _controllers.remove(c.kindId);
      // Remove component
      final list = [..._components];
      list.removeAt(index);
      _components = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return buildShell(
      context: context,
      title: isEdit ? 'Edit product' : 'Add product',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        children: [
          // Id and Name fields
          TextFormField(
            controller: _idController,
            enabled: !(widget.existing?.isProtected ?? false),
            decoration: const InputDecoration(
              labelText: 'Id (stable, e.g., chicken_breast)',
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _components.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = _components[i];
                  final kind = ref.read(widgetRegistryProvider).byId(c.kindId);
                  final unit = kind?.unit ?? '';
                  final ctrl = _controllers[c.kindId]!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          kind?.accentColor ??
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: Icon(kind?.icon ?? Icons.circle, size: 18),
                    ),
                    title: Text(kind?.displayName ?? c.kindId),
                    subtitle: Text(
                      unit.isEmpty ? 'Per 100 g' : 'Per 100 g ($unit)',
                    ),
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
                          onPressed: () => _removeAt(i),
                        ),
                      ],
                    ),
                  );
                },
              ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: loading ? null : _addComponent,
              icon: const Icon(Icons.add),
              label: const Text('Add nutrient'),
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
