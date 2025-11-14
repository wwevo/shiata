// add / edit product instance
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/product_service.dart';

class ProductEditorDialog extends ConsumerStatefulWidget {
  const ProductEditorDialog({super.key, this.entryId, this.productId, this.productName, this.defaultGrams = 100, this.initialTargetAt});

  final String? entryId; // if present → edit existing parent product entry
  final String? productId;
  final String? productName;
  final int defaultGrams;
  final DateTime? initialTargetAt;

  @override
  ConsumerState<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends ConsumerState<ProductEditorDialog> {
  // State variables
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _gramsController;
  bool _isStatic = false;
  DateTime _targetAt = DateTime.now();
  bool _saving = false;
  bool _loading = false;
  String? _productId;
  String? _productName;

  @override
  void initState() {
    super.initState();
    _gramsController = TextEditingController(text: widget.defaultGrams.toString());
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
    setState(() => _loading = true);
    final entries = ref.read(entriesRepositoryProvider);
    if (entries == null) {
      if (mounted) setState(() => _loading = false);
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
      _targetAt = DateTime.fromMillisecondsSinceEpoch(rec.targetAt, isUtc: true).toLocal();
      _isStatic = rec.isStatic;
      _productId = rec.productId ?? _productId;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_targetAt),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (time == null) return;
    if (!context.mounted) return;
    setState(() {
      _targetAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final grams = int.tryParse(_gramsController.text) ?? widget.defaultGrams;
    final service = ref.read(productServiceProvider);
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service not ready')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.entryId != null) {
        // Edit existing parent: update grams/static and recompute children
        await service.updateParentAndChildren(
          parentEntryId: widget.entryId!,
          productGrams: grams,
          isStatic: _isStatic,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${_productName ?? 'Product'} • $grams g')),
        );
        if (closeAfter) Navigator.of(context).pop();
      } else {
        // Create new parent+children
        if (_productId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No product selected')));
          return;
        }
        final id = await service.createProductEntry(
          productId: _productId!,
          productGrams: grams,
          targetAtLocal: _targetAt,
          isStatic: _isStatic,
        );
        if (!context.mounted) return;
        if (id == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not defined yet')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${_productName ?? 'Product'} • $grams g')),
          );
          if (closeAfter) Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.entryId != null;

    return AlertDialog(
      title: Text(isEdit
          ? '${_productName ?? 'Product'} — Edit'
          : '${_productName ?? 'Product'} — Add'),
      content: _loading
          ? const SizedBox(
        width: 400,
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      )
          : SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
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
                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '100'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final val = int.tryParse(v ?? '');
                          if (val == null) return 'Enter an integer';
                          if (val <= 0 || val > 2000) return 'Must be 1–2000';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () {
                            final val = int.tryParse(_gramsController.text) ?? widget.defaultGrams;
                            final next = (val + 10).clamp(1, 2000);
                            _gramsController.text = next.toString();
                          },
                          icon: const Icon(Icons.add),
                          tooltip: '+10',
                        ),
                        IconButton(
                          onPressed: () {
                            final val = int.tryParse(_gramsController.text) ?? widget.defaultGrams;
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
                  onPressed: () => _pickDateTime(context),
                  icon: const Icon(Icons.schedule),
                  label: Text('${_targetAt.toLocal()}'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isStatic,
                  onChanged: (v) => setState(() => _isStatic = v),
                  title: const Text('Static (don\'t update if product changes)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => _save(context, closeAfter: false),
          child: const Text('Save'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(context, closeAfter: true),
          child: const Text('Save & Close'),
        ),
      ],
    );
  }
}
