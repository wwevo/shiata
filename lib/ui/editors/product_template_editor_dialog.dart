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
import '../widgets/editor_dialog_actions.dart';
import '../widgets/inline_error.dart';
import '../widgets/validation_rules.dart';

class ProductTemplateEditorDialog extends ConsumerStatefulWidget {
  const ProductTemplateEditorDialog({
    super.key,
    required this.productId,
    this.productName, // for new products (if not in DB yet)
  });

  final String productId;
  final String? productName;

  @override
  ConsumerState<ProductTemplateEditorDialog> createState() =>
      _ProductTemplateEditorDialogState();
}

class _ProductTemplateEditorDialogState
    extends ConsumerState<ProductTemplateEditorDialog> {
  // State variables
  final _formKey = GlobalKey<FormState>();
  List<ProductComponent> _components = const [];
  bool _loading = true;
  bool _saving = false;
  String _productName = '';
  final Map<String, TextEditingController> _controllers = {};
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(productsRepositoryProvider);
    if (repo != null) {
      final def = await repo.getProduct(widget.productId);
      final comps = await repo.getComponents(widget.productId);
      if (mounted) {
        setState(() {
          // If product doesn't exist in DB, use provided name (creating new)
          _productName = def?.name ?? widget.productName ?? widget.productId;
          _components = comps;
          _loading = false;
        });
        // Initialize controllers for each component
        for (final c in comps) {
          _controllers[c.kindId] = TextEditingController(
            text: fmtDouble(c.amountPerGram),
          );
        }
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    // Clear previous errors
    setState(() => _saveError = null);

    // UI validation first
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    // Capture context-dependent objects BEFORE any async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final repo = ref.read(productsRepositoryProvider);
    final svc = ref.read(productServiceProvider);
    if (repo == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      // Check if product exists in DB
      final existing = await repo.getProduct(widget.productId);
      if (existing == null) {
        // Create new product first
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await repo.upsertProduct(
          ProductDef(
            id: widget.productId,
            name: widget.productName ?? widget.productId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      // Read values from controllers and update components
      final updatedComponents = <ProductComponent>[];
      for (final c in _components) {
        final ctrl = _controllers[c.kindId];
        final amount = parseDouble(ctrl?.text) ?? 0.0;
        updatedComponents.add(
          ProductComponent(
            productId: widget.productId,
            kindId: c.kindId,
            amountPerGram: amount,
          ),
        );
      }
      await repo.setComponents(widget.productId, updatedComponents);

      if (!context.mounted) return;

      // Ask to propagate to non-static instances
      final doProp = await showDialog<bool>(
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
      );

      if (doProp == true && svc != null) {
        await svc.updateAllEntriesForProductToCurrentFormula(widget.productId);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Updated existing entries')),
        );
      } else {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Saved template')));
      }

      if (mounted) setState(() => _saving = false);
      if (closeAfter && mounted) {
        navigator.pop();
      }
    } on ArgumentError catch (e) {
      // User input error - show inline
      if (mounted) {
        setState(() {
          _saveError = e.message;
          _saving = false;
        });
      }
    } on StateError catch (e) {
      // Constraint violation - show inline
      if (mounted) {
        setState(() {
          _saveError = e.message;
          _saving = false;
        });
      }
    } catch (e) {
      // Unexpected error - debug only
      debugPrint('Unexpected error in save: $e');
      if (mounted) {
        setState(() {
          _saveError = 'An unexpected error occurred';
          _saving = false;
        });
      }
    }
  }

  Future<void> _addComponent() async {
    final registry = ref.read(widgetRegistryProvider);
    final kinds = registry.kinds.toList();
    final picked = await showDialog<WidgetKind?>(
      context: context,
      builder: (ctx) => _AddComponentDialog(kinds: kinds),
    );
    if (picked == null) return;
    setState(() {
      // Remove if already exists
      _components = [..._components.where((c) => c.kindId != picked.id)];
      // Add new component with initial value 0
      _components = [
        ..._components,
        ProductComponent(
          productId: widget.productId,
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
    return AlertDialog(
      title: Text(
        'Edit: ${_productName.isEmpty ? widget.productId : _productName}',
      ),
      content: _loading
          ? const SizedBox(
              width: 500,
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 500,
              height: 400,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Show repository errors inline
                    if (_saveError != null) InlineError(message: _saveError!),
                    Expanded(
                    child: _components.isEmpty
                        ? const Center(child: Text('No components yet'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _components.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final c = _components[i];
                              final kind = ref
                                  .read(widgetRegistryProvider)
                                  .byId(c.kindId);
                              final unit = kind?.unit ?? '';
                              final ctrl = _controllers[c.kindId]!;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      kind?.accentColor ??
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  child: Icon(
                                    kind?.icon ?? Icons.circle,
                                    size: 18,
                                  ),
                                ),
                                title: Text(kind?.displayName ?? c.kindId),
                                subtitle: Text(
                                  unit.isEmpty
                                      ? 'Per 100 g'
                                      : 'Per 100 g ($unit)',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        controller: ctrl,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
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
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _addComponent,
                      icon: const Icon(Icons.add),
                      label: const Text('Add nutrient'),
                    ),
                    ),
                  ],
                ),
              ),
            ),
      actions: editorDialogActions(
        context: context,
        onSave: ({required closeAfter}) =>
            _save(context, closeAfter: closeAfter),
        isSaving: _saving,
      ),
    );
  }
}

class _AddComponentDialog extends StatefulWidget {
  const _AddComponentDialog({required this.kinds});

  final List<WidgetKind> kinds;

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  WidgetKind? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add nutrient'),
      content: DropdownButton<WidgetKind>(
        value: _selected,
        hint: const Text('Select nutrient'),
        isExpanded: true,
        items: [
          for (final k in widget.kinds)
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
            Navigator.of(context).pop(k);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
