import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/widgets/widget_kind.dart';

/// Generic integer-only nutrient editor driven by WidgetKind metadata.
class KindInstanceEditorDialog extends ConsumerStatefulWidget {
  const KindInstanceEditorDialog({
    super.key,
    required this.kind,
    this.entryId,
    this.initialTargetAt,
  });

  final WidgetKind kind;
  final String? entryId; // if present → edit mode
  final DateTime? initialTargetAt; // prefill for create

  @override
  ConsumerState<KindInstanceEditorDialog> createState() => _KindInstanceEditorDialogState();
}

class _KindInstanceEditorDialogState extends ConsumerState<KindInstanceEditorDialog> {
  // Helper methods
  String _fmtDouble(num v) {
    final s = (v.toDouble()).toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double? _parseDouble(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  // State variables
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late DateTime _targetAt;
  late bool _showInCalendar;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '0');
    _targetAt = widget.initialTargetAt ?? DateTime.now();
    _showInCalendar = widget.kind.defaultShowInCalendar;
    if (widget.entryId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final repo = ref.read(entriesRepositoryProvider);
    if (repo != null) {
      final rec = await repo.getById(widget.entryId!);
      if (rec != null) {
        try {
          final map = jsonDecode(rec.payloadJson) as Map<String, dynamic>;
          final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
          _amountController.text = _fmtDouble(amount);
        } catch (_) {}
        _targetAt = DateTime.fromMillisecondsSinceEpoch(rec.targetAt, isUtc: true).toLocal();
        _showInCalendar = rec.showInCalendar;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _amountController.dispose();
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

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database not ready')),
      );
      return;
    }
    final amountToStore = _parseDouble(_amountController.text) ?? 0.0;
    try {
      if (widget.entryId != null) {
        await repo.update(widget.entryId!, {
          'target_at': _targetAt.toUtc().millisecondsSinceEpoch,
          'payload_json': jsonEncode({'amount': amountToStore, 'unit': widget.kind.unit}),
          'show_in_calendar': _showInCalendar ? 1 : 0,
          'schema_version': 1,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated ${widget.kind.displayName}')),
          );
          Navigator.of(context).pop();
        }
      } else {
        await repo.create(
          widgetKind: widget.kind.id,
          targetAtLocal: _targetAt,
          payload: {'amount': amountToStore, 'unit': widget.kind.unit},
          showInCalendar: _showInCalendar,
          schemaVersion: 1,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved ${widget.kind.displayName}')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.entryId != null;

    return AlertDialog(
      title: Text(isEdit
          ? '${widget.kind.displayName} — Edit'
          : '${widget.kind.displayName} — Create'),
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
                Text('Amount (${widget.kind.unit})', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) {
                          final val = _parseDouble(v);
                          if (val == null) return 'Enter a number';
                          final min = widget.kind.minValue.toDouble();
                          final max = widget.kind.maxValue.toDouble();
                          if (val < min || val > max) {
                            return 'Must be ${_fmtDouble(min)}–${_fmtDouble(max)}';
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
                            final current = _parseDouble(_amountController.text) ?? 0.0;
                            final next = (current + 1.0).clamp(
                              widget.kind.minValue.toDouble(),
                              widget.kind.maxValue.toDouble(),
                            );
                            _amountController.text = _fmtDouble(next);
                          },
                          icon: const Icon(Icons.add),
                          tooltip: '+1',
                        ),
                        IconButton(
                          onPressed: () {
                            final current = _parseDouble(_amountController.text) ?? 0.0;
                            final next = (current - 1.0).clamp(
                              widget.kind.minValue.toDouble(),
                              widget.kind.maxValue.toDouble(),
                            );
                            _amountController.text = _fmtDouble(next);
                          },
                          icon: const Icon(Icons.remove),
                          tooltip: '-1',
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
                  value: _showInCalendar,
                  onChanged: (v) => setState(() => _showInCalendar = v),
                  title: const Text('Show in calendar'),
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
        FilledButton(
          onPressed: () => _save(context),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
