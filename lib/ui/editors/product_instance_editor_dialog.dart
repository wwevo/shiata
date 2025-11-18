// add / edit product instance
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/product_service.dart';
import '../widgets/editor_dialog_actions.dart';
import '../widgets/inline_error.dart';

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
  String? _saveError;

  @override
  void initState() {
    super.initState();
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
      _targetAt = DateTime.fromMillisecondsSinceEpoch(
        rec.targetAt,
        isUtc: true,
      ).toLocal();
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
      _targetAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
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

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    // Clear previous errors
    setState(() => _saveError = null);

    // UI validation first
    if (!_formKey.currentState!.validate()) return;

    final grams = int.tryParse(_gramsController.text) ?? widget.defaultGrams;
    final service = ref.read(productServiceProvider);
    if (service == null) return;

    setState(() => _saving = true);

    // Capture context-dependent objects before async gap
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (widget.entryId != null) {
        // Edit existing parent: update grams/static and recompute children
        await service.updateParentAndChildren(
          parentEntryId: widget.entryId!,
          productGrams: grams,
          isStatic: _isStatic,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Updated ${_productName ?? 'Product'} • $grams g'),
          ),
        );
        if (closeAfter && mounted) navigator.pop();
      } else {
        // Create new parent+children
        if (_productId == null) {
          if (mounted) {
            setState(() {
              _saveError = 'No product selected';
              _saving = false;
            });
          }
          return;
        }
        final id = await service.createProductEntry(
          productId: _productId!,
          productGrams: grams,
          targetAtLocal: _targetAt,
          isStatic: _isStatic,
        );
        if (!mounted) return;
        if (id == null) {
          if (mounted) {
            setState(() {
              _saveError = 'Product not defined yet';
              _saving = false;
            });
          }
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Added ${_productName ?? 'Product'} • $grams g'),
            ),
          );
          if (closeAfter && mounted) navigator.pop();
        }
      }
      if (mounted) setState(() => _saving = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.entryId != null;

    return AlertDialog(
      title: Text(
        isEdit
            ? '${_productName ?? 'Product'} — Edit'
            : '${_productName ?? 'Product'} — Add',
      ),
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
                      // Show repository errors inline
                      if (_saveError != null) InlineError(message: _saveError!),
                      Text(
                        'Amount (grams)',
                        style: theme.textTheme.titleMedium,
                      ),
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
                                final val = int.tryParse(v ?? '');
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
                                      int.tryParse(_gramsController.text) ??
                                      widget.defaultGrams;
                                  final next = (val + 10).clamp(1, 2000);
                                  _gramsController.text = next.toString();
                                },
                                icon: const Icon(Icons.add),
                                tooltip: '+10',
                              ),
                              IconButton(
                                onPressed: () {
                                  final val =
                                      int.tryParse(_gramsController.text) ??
                                      widget.defaultGrams;
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
                        onChanged: _handleStaticToggle,
                        title: const Text(
                          'Static (don\'t update if product changes)',
                        ),
                      ),
                    ],
                  ),
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
