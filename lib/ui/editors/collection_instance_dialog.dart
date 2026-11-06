import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/collection_service.dart';
import '../../data/repo/collections_repository.dart';
import '../../data/repo/products_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/add_component_menu.dart';
import '../widgets/entry_date_time_picker.dart';
import '../widgets/selection_dialog.dart';
import 'editor_form_support.dart';

class CollectionInstantiateDialog extends ConsumerStatefulWidget {
  const CollectionInstantiateDialog({
    super.key,
    this.entryId,
    this.collectionId,
    this.initialTarget,
  });

  final String? entryId; // if present → edit existing collection instance
  final String? collectionId; // required for create, optional for edit
  final DateTime? initialTarget; // required for create, optional for edit

  @override
  ConsumerState<CollectionInstantiateDialog> createState() =>
      CollectionInstantiateDialogState();
}

class CollectionInstantiateDialogState
    extends ConsumerState<CollectionInstantiateDialog>
    with EditorDialogShell {
  // State variables
  String? _collectionId;
  String _collectionName = '';
  DateTime _targetAt = DateTime.now();
  bool _isStatic = false;
  bool _showInCalendar = true;
  List<CollectionComponentDef> _components = const [];
  final Map<String, TextEditingController> _kindCtrls = {};
  final Map<String, TextEditingController> _productCtrls = {};
  final Map<String, bool> _selectedIngredients = {};

  @override
  void initState() {
    super.initState();
    loading = true;
    _collectionId = widget.collectionId;
    if (widget.initialTarget != null) {
      _targetAt = widget.initialTarget!;
    }
    if (widget.entryId != null) {
      _loadExisting();
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    for (final c in _kindCtrls.values) {
      c.dispose();
    }
    for (final c in _productCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => loading = true);
    final entries = ref.read(entriesRepositoryProvider);
    final collectionsRepo = ref.read(collectionsRepositoryProvider);
    if (entries == null || collectionsRepo == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final entry = await entries.getById(widget.entryId!);
    if (entry != null) {
      _collectionId = entry.recipeId;
      try {
        final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
        _collectionName = payload['name'] as String? ?? '';
      } catch (_) {}
      _targetAt = DateTime.fromMillisecondsSinceEpoch(
        entry.targetAt,
        isUtc: true,
      ).toLocal();
      _isStatic = entry.isStatic;
      _showInCalendar = entry.showInCalendar;

      // Load children and populate controllers with their values
      if (_collectionId != null) {
        final children = await entries.listChildrenOfParent(widget.entryId!);
        final comps = await collectionsRepo.getComponents(_collectionId!);

        // Clear old controllers
        for (final ctrl in _kindCtrls.values) {
          ctrl.dispose();
        }
        for (final ctrl in _productCtrls.values) {
          ctrl.dispose();
        }
        _kindCtrls.clear();
        _productCtrls.clear();
        _selectedIngredients.clear();

        // Determine which ingredients are present in children
        for (final c in comps) {
          final typeStr = c.type.toString();
          bool isSelected = false;
          if (typeStr.endsWith('kind')) {
            // Find the child entry for this kind
            final childEntry = children
                .where((e) => e.widgetKind == c.compId)
                .firstOrNull;
            isSelected = childEntry != null;
            double currentAmount = c.amount ?? 0.0;
            if (childEntry != null) {
              try {
                final childPayload =
                    jsonDecode(childEntry.payloadJson) as Map<String, dynamic>;
                currentAmount =
                    (childPayload['amount'] as num?)?.toDouble() ??
                    currentAmount;
              } catch (_) {}
            }
            _kindCtrls[c.compId] = TextEditingController(
              text: fmtDouble(currentAmount),
            );
          } else {
            // Find the product child
            final productChild = children
                .where(
                  (e) => e.widgetKind == 'product' && e.productId == c.compId,
                )
                .firstOrNull;
            isSelected = productChild != null;
            int currentGrams = c.grams ?? 0;
            if (productChild != null) {
              currentGrams = productChild.productGrams ?? currentGrams;
            }
            _productCtrls[c.compId] = TextEditingController(
              text: currentGrams.toString(),
            );
          }
          _selectedIngredients[c.compId] = isSelected;
        }

        if (mounted) {
          setState(() {
            _components = comps;
            loading = false;
          });
        }
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _load() async {
    final repo = ref.read(collectionsRepositoryProvider);
    if (repo != null && _collectionId != null) {
      final def = await repo.getCollection(_collectionId!);
      final comps = await repo.getComponents(_collectionId!);
      if (mounted) {
        setState(() {
          _collectionName = def?.name ?? '';
          _components = comps;
          loading = false;
        });
      }
      // Clear old controllers
      for (final ctrl in _kindCtrls.values) {
        ctrl.dispose();
      }
      for (final ctrl in _productCtrls.values) {
        ctrl.dispose();
      }
      _kindCtrls.clear();
      _productCtrls.clear();
      _selectedIngredients.clear();

      // Initialize controllers with template defaults, all selected by default
      for (final c in comps) {
        final typeStr = c.type.toString();
        if (typeStr.endsWith('kind')) {
          _kindCtrls[c.compId] = TextEditingController(
            text: fmtDouble(c.amount ?? 0.0),
          );
        } else {
          _productCtrls[c.compId] = TextEditingController(
            text: (c.grams ?? 0).toString(),
          );
        }
        _selectedIngredients[c.compId] = true;
      }
    } else {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handleStaticToggle(bool newValue) async {
    // If switching from static to dynamic, offer to reset to template values
    if (_isStatic && !newValue) {
      final shouldReset = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset to template?'),
          content: const Text(
            'Do you want to reset all values to the collection template defaults?\n\n'
            'This will overwrite any custom values you\'ve entered.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep values'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reset'),
            ),
          ],
        ),
      );

      if (shouldReset == true) {
        // Reload template values
        await _load();
      }
    }

    setState(() => _isStatic = newValue);
  }

  Future<void> _showAddMenu() async {
    final registry = ref.read(widgetRegistryProvider);
    final productsRepo = ref.read(productsRepositoryProvider);
    final collectionsRepo = ref.read(collectionsRepositoryProvider);

    // Step 1: Ask what type of component to add
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          const AddComponentMenu(enabledTypes: {'kind', 'product'}),
    );

    if (type == null || !mounted) return;

    CollectionComponentDef? newComponent;

    // Step 2: Show the appropriate picker based on type
    switch (type) {
      case 'kind':
        final kind = await showDialog<WidgetKind?>(
          context: context,
          builder: (ctx) => SelectionDialog<WidgetKind>(
            title: 'Add kind',
            hint: 'Select kind',
            items: registry.kinds.toList(),
            itemLabel: (k) => k.displayName,
          ),
        );

        if (kind != null) {
          newComponent = CollectionComponentDef.kind(
            collectionId: _collectionId ?? '',
            compId: kind.id,
            amount: 0.0,
          );
        }
        break;

      case 'product':
        if (productsRepo == null) return;

        final products = await productsRepo.listProducts();
        if (!mounted) return;

        final product = await showDialog<ProductDef?>(
          context: context,
          builder: (ctx) => SelectionDialog<ProductDef>(
            title: 'Add product',
            hint: 'Select product',
            items: products,
            itemLabel: (p) => p.name,
          ),
        );

        if (product != null) {
          newComponent = CollectionComponentDef.product(
            collectionId: _collectionId ?? '',
            compId: product.id,
            grams: 100,
          );
        }
        break;
    }

    if (!mounted) return;
    if (newComponent == null) return;

    // Step 3: Ask if this should be saved to template or one-shot
    final saveToTemplate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save to template?'),
        content: const Text(
          'Do you want to save this ingredient to the collection template?\n\n'
          'Yes: Save to template (persistent)\n'
          'No: One-shot only (makes entry static)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('One-shot'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save to template'),
          ),
        ],
      ),
    );

    if (saveToTemplate == null) return;

    final component = newComponent; // non-null due to check above
    if (saveToTemplate && collectionsRepo != null && _collectionId != null) {
      // Save to template
      final updatedComponents = List<CollectionComponentDef>.from(_components);
      updatedComponents.add(component);
      await collectionsRepo.setComponents(_collectionId!, updatedComponents);
    } else {
      // One-shot - make entry static
      setState(() => _isStatic = true);
    }

    // Add to current instance
    setState(() {
      _components = List<CollectionComponentDef>.from(_components)
        ..add(component);
      if (component.type == CollectionComponentType.kind) {
        _kindCtrls[component.compId] = TextEditingController(text: '0');
      } else {
        _productCtrls[component.compId] = TextEditingController(text: '100');
      }
      _selectedIngredients[component.compId] = true;
    });
  }

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final svc = ref.read(collectionServiceProvider);
        if (svc == null) return;

        final kindOverrides = <String, double>{};
        final productOverrides = <String, int>{};
        _kindCtrls.forEach((k, v) {
          final d = parseDouble(v.text);
          if (d != null) kindOverrides[k] = d;
        });
        _productCtrls.forEach((k, v) {
          final g = parseInt(v.text);
          if (g != null) productOverrides[k] = g;
        });

        if (widget.entryId != null) {
          // Edit existing collection instance
          await svc.updateCollectionInstance(
            parentEntryId: widget.entryId!,
            targetAtLocal: _targetAt,
            selectedIngredients: _selectedIngredients,
            kindOverrides: kindOverrides.isEmpty ? null : kindOverrides,
            productGramOverrides: productOverrides.isEmpty
                ? null
                : productOverrides,
            isStatic: _isStatic,
            showInCalendar: _showInCalendar,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Updated ${_collectionName.isEmpty ? 'Collection' : _collectionName}',
                ),
              ),
            );
          }
        } else {
          // Create new collection instance
          if (_collectionId == null) {
            throw ArgumentError('No collection selected');
          }
          await svc.createCollectionEntry(
            collectionId: _collectionId!,
            targetAtLocal: _targetAt,
            selectedIngredients: _selectedIngredients,
            kindOverrides: kindOverrides.isEmpty ? null : kindOverrides,
            productGramOverrides: productOverrides.isEmpty
                ? null
                : productOverrides,
            showParentInCalendar: _showInCalendar,
            isStatic: _isStatic,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Added ${_collectionName.isEmpty ? 'Collection' : _collectionName}',
                ),
              ),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);
    final isEdit = widget.entryId != null;

    return buildShell(
      context: context,
      title: isEdit
          ? 'Edit ${_collectionName.isEmpty ? 'collection' : _collectionName}'
          : 'Instantiate ${_collectionName.isEmpty ? _collectionId ?? 'collection' : _collectionName}',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EntryDateTimePicker(
            value: _targetAt,
            onChanged: (value) => setState(() => _targetAt = value),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isStatic,
            onChanged: _handleStaticToggle,
            title: const Text(
              'Static (don\'t update if collection template changes)',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showInCalendar,
            onChanged: (v) => setState(() => _showInCalendar = v),
            title: const Text('Show in calendar'),
          ),
          const SizedBox(height: 12),
          if (_components.isEmpty)
            const SizedBox(
              height: 100,
              child: Center(
                child: Text('No components in this collection yet'),
              ),
            )
          else ...[
            for (final c in _components)
              Builder(
                builder: (ctx) {
                  final typeStr = c.type.toString();
                  final isSelected = _selectedIngredients[c.compId] ?? true;
                  if (typeStr.endsWith('kind')) {
                    final k = registry.byId(c.compId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                _selectedIngredients[c.compId] = v ?? false;
                              });
                            },
                            title: Text(k?.displayName ?? c.compId),
                            subtitle: Text('Unit: ${k?.unit ?? ''}'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 56.0,
                                right: 8.0,
                                bottom: 8.0,
                              ),
                              child: TextFormField(
                                controller: _kindCtrls[c.compId],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  hintText: 'Amount',
                                  isDense: true,
                                ),
                                validator: ValidationRules.nonNegativeAmount,
                              ),
                            ),
                        ],
                      ),
                    );
                  } else {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) {
                              setState(() {
                                _selectedIngredients[c.compId] = v ?? false;
                              });
                            },
                            title: Text('Product: ${c.compId}'),
                            subtitle: const Text('Unit: g'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 56.0,
                                right: 8.0,
                                bottom: 8.0,
                              ),
                              child: TextFormField(
                                controller: _productCtrls[c.compId],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'Grams',
                                  isDense: true,
                                ),
                                validator: ValidationRules.positiveGrams,
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                },
              ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: loading ? null : _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('Add on the fly'),
            ),
          ),
        ],
      ),
    );
  }
}
