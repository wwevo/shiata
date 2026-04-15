// add / edit product instance
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/product_service.dart';
import '../../utils/formatters.dart';
import '../widgets/date_time_picker.dart';
import '../widgets/editor_dialog_shell.dart';

class ProductEditorDialog extends ConsumerStatefulWidget {
  const ProductEditorDialog({
    super.key,
    this.entryId,
    this.productId,
    this.productName,
    this.defaultGrams = 100,
    this.initialTargetAt,
  });

  final String? entryId; // if present → edit existing parent product entry
  final String? productId;
  final String? productName;
  final int defaultGrams;
  final DateTime? initialTargetAt;

  @override
  ConsumerState<ProductEditorDialog> createState() =>
      _ProductEditorDialogState();
}

class _ProductEditorDialogState extends ConsumerState<ProductEditorDialog>
    with EditorDialogShell {
  // State variables
  late final TextEditingController _gramsController;
  bool _isStatic = false;
  DateTime _targetAt = DateTime.now();
  bool _showInCalendar = true;
  String? _productId;
  String? _productName;

  @override
  void initState() {
    super.initState();
    loading = false;
    _gramsController = TextEditingController(
      text: widget.defaultGrams.toString(),
    );
    _productId = widget.productId;
    _productName = widget.productName;
    if (widget.initialTargetAt != null) {
      _targetAt = widget.initialTargetAt!;
    }
    if (widget.entryId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => loading = true);
    final entries = ref.read(entriesRepositoryProvider);
    if (entries == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final rec = await entries.getById(widget.entryId!);
    if (rec != null) {
      try {
        final map = jsonDecode(rec.payloadJson) as Map<String, dynamic>;
        final grams = (map['grams'] as num?)?.toInt();
        final name = map['name'] as String?;
        if (grams != null) _gramsController.text = grams.toString();
        _productName = name ?? _productName;
      } catch (_) {}
      _targetAt = DateTime.fromMillisecondsSinceEpoch(
        rec.targetAt,
        isUtc: true,
      ).toLocal();
      _isStatic = rec.isStatic;
      _productId = rec.productId ?? _productId;
      _showInCalendar = rec.showInCalendar;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> _handlePickDateTime(BuildContext context) async {
    final picked = await pickDateTime(context, _targetAt);
    if (picked != null) {
      setState(() => _targetAt = picked);
    }
  }

  Future<void> _handleStaticToggle(bool newValue) async {
    // If switching from static to dynamic, warn about recomputation
    if (_isStatic && !newValue) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset to template?'),
          content: const Text(
            'Switching to dynamic will recompute all nutrients from the product template when you save.\n\n'
            'Any custom nutrient values will be replaced with template values.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    setState(() => _isStatic = newValue);
  }

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final grams = parseInt(_gramsController.text) ?? widget.defaultGrams;
        final service = ref.read(productServiceProvider);
        if (service == null) return;

        if (widget.entryId != null) {
          // Edit existing parent: update grams/static and recompute children
          await service.updateParentAndChildren(
            parentEntryId: widget.entryId!,
            productGrams: grams,
            isStatic: _isStatic,
            showInCalendar: _showInCalendar,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Updated ${_productName ?? 'Product'} • $grams g'),
              ),
            );
          }
        } else {
          // Create new parent+children
          if (_productId == null) {
            throw ArgumentError('No product selected');
          }
          final id = await service.createProductEntry(
            productId: _productId!,
            productGrams: grams,
            targetAtLocal: _targetAt,
            isStatic: _isStatic,
            showInCalendar: _showInCalendar,
          );
          if (id == null) {
            throw StateError('Product not defined yet');
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${_productName ?? 'Product'} • $grams g'),
                ),
              );
            }
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.entryId != null;

    return buildShell(
      context: context,
      title: isEdit
          ? 'Edit ${_productName ?? 'product'}'
          : 'Add ${_productName ?? 'product'}',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount (grams)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _gramsController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '100',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final val = parseInt(v);
                    if (val == null) return 'Enter an integer';
                    if (val <= 0 || val > 2000) {
                      return 'Must be 1–2000';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                      final val =
                          parseInt(_gramsController.text) ?? widget.defaultGrams;
                      final next = (val + 10).clamp(1, 2000);
                      _gramsController.text = next.toString();
                    },
                    icon: const Icon(Icons.add),
                    tooltip: '+10',
                  ),
                  IconButton(
                    onPressed: () {
                      final val =
                          parseInt(_gramsController.text) ?? widget.defaultGrams;
                      final next = (val - 10).clamp(1, 2000);
                      _gramsController.text = next.toString();
                    },
                    icon: const Icon(Icons.remove),
                    tooltip: '-10',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('When', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _handlePickDateTime(context),
            icon: const Icon(Icons.schedule),
            label: Text('${_targetAt.toLocal()}'),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isStatic,
            onChanged: _handleStaticToggle,
            title: const Text('Static (don\'t update if product changes)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _showInCalendar,
            onChanged: (v) => setState(() => _showInCalendar = v),
            title: const Text('Show in calendar'),
          ),
        ],
      ),
    );
  }
}
