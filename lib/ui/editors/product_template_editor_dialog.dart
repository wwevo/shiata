// add/edit product template
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/products_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../widgets/editor_dialog_actions.dart';

class ProductTemplateEditorDialog extends ConsumerStatefulWidget {
  const ProductTemplateEditorDialog({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductTemplateEditorDialog> createState() => _ProductTemplateEditorDialogState();
}

class _ProductTemplateEditorDialogState extends ConsumerState<ProductTemplateEditorDialog> {
  // Helper methods
  String _fmtDouble(double v) {
    final s = v.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double? _parseDouble(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  // State variables
  List<ProductComponent> _components = const [];
  bool _loading = true;
  bool _saving = false;
  String _productName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(productsRepositoryProvider);
    if (repo != null) {
      final def = await repo.getProduct(widget.productId);
      final comps = await repo.getComponents(widget.productId);
      if (mounted) {
        setState(() {
          _productName = def?.name ?? widget.productId;
          _components = comps;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    setState(() => _saving = true);
    final repo = ref.read(productsRepositoryProvider);
    final svc = ref.read(productServiceProvider);
    if (repo == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    // Capture old components for Undo
    final old = await repo.getComponents(widget.productId);
    await repo.setComponents(widget.productId, _components);
    if (!mounted) return;
    // Ask to propagate to non-static instances
    final doProp = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update existing entries?'),
        content: const Text('Apply these changes to all non-static entries for this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
        ],
      ),
    );
    if (doProp == true && svc != null) {
      await svc.updateAllEntriesForProductToCurrentFormula(widget.productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Updated existing entries'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              // Capture messenger before any awaits to avoid using context across async gaps
              final messenger = ScaffoldMessenger.of(context);
              // Restore old components and re-propagate
              await repo.setComponents(widget.productId, old);
              await svc.updateAllEntriesForProductToCurrentFormula(widget.productId);
              if (!mounted) return;
              await _load();
              messenger.showSnackBar(const SnackBar(content: Text('Reverted template changes')));
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved template')));
    }
    if (mounted) setState(() => _saving = false);
    if (closeAfter && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addComponent() async {
    final registry = ref.read(widgetRegistryProvider);
    final kinds = registry.kinds.toList();
    final picked = await showDialog<(WidgetKind, double)?>(
      context: context,
      builder: (ctx) => _AddComponentDialog(kinds: kinds),
    );
    if (picked == null) return;
    final (kind, per100) = picked;
    setState(() {
      _components = [
        ..._components.where((c) => c.kindId != kind.id),
        ProductComponent(productId: widget.productId, kindId: kind.id, amountPerGram: per100),
      ];
    });
  }

  void _removeAt(int index) {
    setState(() {
      final list = [..._components];
      list.removeAt(index);
      _components = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit: ${_productName.isEmpty ? widget.productId : _productName}'),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _components.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = _components[i];
                  final kind = ref.read(widgetRegistryProvider).byId(c.kindId);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: kind?.accentColor ?? Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: Icon(kind?.icon ?? Icons.circle, size: 18),
                    ),
                    title: Text(kind?.displayName ?? c.kindId),
                    subtitle: Text('Per 100 g: ${_fmtDouble(c.amountPerGram)} ${kind?.unit ?? ''}'),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeAt(i),
                    ),
                    onTap: () async {
                      final newVal = await _askForAmount(context, kind, c.amountPerGram);
                      if (newVal != null) {
                        setState(() {
                          _components = [
                            for (final x in _components)
                              if (x.kindId == c.kindId)
                                ProductComponent(productId: x.productId, kindId: x.kindId, amountPerGram: newVal)
                              else
                                x,
                          ];
                        });
                      }
                    },
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
      actions: editorDialogActions(
        context: context,
        onSave: ({required closeAfter}) => _save(context, closeAfter: closeAfter),
        isSaving: _saving,
      ),
    );
  }

  Future<double?> _askForAmount(BuildContext context, WidgetKind? kind, double current) async {
    final c = TextEditingController(text: _fmtDouble(current));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Per 100 g (${kind?.unit ?? ''})'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(hintText: 'number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = _parseDouble(c.text.trim());
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

class _AddComponentDialog extends StatefulWidget {
  const _AddComponentDialog({required this.kinds});
  final List<WidgetKind> kinds;

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  WidgetKind? _selected;
  final _amountController = TextEditingController(text: '0');

  double? _parse(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add component'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<WidgetKind>(
            initialValue: _selected,
            items: [
              for (final k in widget.kinds)
                DropdownMenuItem(value: k, child: Text(k.displayName)),
            ],
            onChanged: (v) => setState(() => _selected = v),
            decoration: const InputDecoration(labelText: 'Kind'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Per 100 g (number)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final k = _selected;
            final v = double.tryParse(_amountController.text.trim());
            if (k == null || v == null || v < 0) return;
            Navigator.of(context).pop((k, v));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
