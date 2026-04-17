import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../widgets/date_time_picker.dart';
import '../widgets/editor_dialog_shell.dart';

/// Generic integer-only editor driven by WidgetKind metadata.
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
  ConsumerState<KindInstanceEditorDialog> createState() =>
      _KindInstanceEditorDialogState();
}

class _KindInstanceEditorDialogState
    extends ConsumerState<KindInstanceEditorDialog> with EditorDialogShell {
  // State variables
  late final TextEditingController _amountController;
  late DateTime _targetAt;
  late bool _showInCalendar;

  @override
  void initState() {
    super.initState();
    loading = false;
    _amountController = TextEditingController(text: '0');
    _targetAt = widget.initialTargetAt ?? DateTime.now();
    _showInCalendar = widget.kind.defaultShowInCalendar;
    if (widget.entryId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => loading = true);
    final repo = ref.read(entriesRepositoryProvider);
    if (repo != null) {
      final rec = await repo.getById(widget.entryId!);
      if (rec != null) {
        try {
          final map = jsonDecode(rec.payloadJson) as Map<String, dynamic>;
          final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
          _amountController.text = fmtDouble(amount);
        } catch (_) {}
        _targetAt = DateTime.fromMillisecondsSinceEpoch(
          rec.targetAt,
          isUtc: true,
        ).toLocal();
        _showInCalendar = rec.showInCalendar;
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handlePickDateTime(BuildContext context) async {
    final picked = await pickDateTime(context, _targetAt);
    if (picked != null) {
      setState(() => _targetAt = picked);
    }
  }

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final repo = ref.read(entriesRepositoryProvider);
        if (repo == null) return;

        final amountToStore = parseDouble(_amountController.text) ?? 0.0;

        if (widget.entryId != null) {
          await repo.update(widget.entryId!, {
            'target_at': _targetAt.toUtc().millisecondsSinceEpoch,
            'payload_json': jsonEncode({
              'amount': amountToStore,
              'unit': widget.kind.unit,
            }),
            'show_in_calendar': _showInCalendar ? 1 : 0
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Updated ${widget.kind.displayName}')),
            );
          }
        } else {
          await repo.create(
            widgetKind: widget.kind.id,
            targetAtLocal: _targetAt,
            payload: {'amount': amountToStore, 'unit': widget.kind.unit},
            showInCalendar: _showInCalendar,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved ${widget.kind.displayName}')),
            );
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
          ? 'Edit ${widget.kind.displayName}'
          : 'Add ${widget.kind.displayName}',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount (${widget.kind.unit})',
            style: theme.textTheme.titleMedium,
          ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) {
                    final val = parseDouble(v);
                    if (val == null) return 'Enter a number';
                    final min = widget.kind.minValue.toDouble();
                    final max = widget.kind.maxValue.toDouble();
                    if (val < min || val > max) {
                      return 'Must be ${fmtDouble(min)}–${fmtDouble(max)}';
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
                      final current = parseDouble(_amountController.text) ?? 0.0;
                      final next = (current + 1.0).clamp(
                        widget.kind.minValue.toDouble(),
                        widget.kind.maxValue.toDouble(),
                      );
                      _amountController.text = fmtDouble(next);
                    },
                    icon: const Icon(Icons.add),
                    tooltip: '+1',
                  ),
                  IconButton(
                    onPressed: () {
                      final current = parseDouble(_amountController.text) ?? 0.0;
                      final next = (current - 1.0).clamp(
                        widget.kind.minValue.toDouble(),
                        widget.kind.maxValue.toDouble(),
                      );
                      _amountController.text = fmtDouble(next);
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
            onPressed: () => _handlePickDateTime(context),
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
    );
  }
}
