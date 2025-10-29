import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'dart:convert';

class CarbohydrateEditorScreen extends ConsumerStatefulWidget {
  const CarbohydrateEditorScreen({super.key, this.entryId, this.initialTargetAt});

  final String? entryId; // if present → edit mode
  final DateTime? initialTargetAt; // prefill for create

  @override
  ConsumerState<CarbohydrateEditorScreen> createState() => _CarbohydrateEditorScreenState();
}

class _CarbohydrateEditorScreenState extends ConsumerState<CarbohydrateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gramsController = TextEditingController(text: '0');
  DateTime _targetAt = DateTime.now();
  bool _showInCalendar = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTargetAt != null) {
      _targetAt = widget.initialTargetAt!;
    }
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
          final grams = (map['grams'] as num?)?.toInt() ?? 0;
          _gramsController.text = grams.toString();
        } catch (_) {}
        _targetAt = DateTime.fromMillisecondsSinceEpoch(rec.targetAt, isUtc: true).toLocal();
        _showInCalendar = rec.showInCalendar;
      }
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

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final grams = int.tryParse(_gramsController.text) ?? 0;
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database not ready')),
      );
      return;
    }
    try {
      if (widget.entryId != null) {
        await repo.update(widget.entryId!, {
          'target_at': _targetAt.toUtc().millisecondsSinceEpoch,
          'payload_json': jsonEncode({'grams': grams}),
          'show_in_calendar': _showInCalendar ? 1 : 0,
          'schema_version': 1,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Updated Carbohydrate entry')),
          );
          Navigator.of(context).pop();
        }
      } else {
        await repo.create(
          widgetKind: 'carbohydrate',
          targetAtLocal: _targetAt,
          payload: {'grams': grams},
          showInCalendar: _showInCalendar,
          schemaVersion: 1,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved Carbohydrate entry')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entryId == null ? 'Carbohydrate — Create' : 'Carbohydrate — Edit'),
        actions: [
          IconButton(
            onPressed: () => _save(context),
            icon: const Icon(Icons.check),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
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
                              hintText: '0',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final val = int.tryParse(v ?? '');
                              if (val == null) return 'Enter an integer';
                              if (val < 0 || val > 400) return 'Must be 0–400';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () {
                                final val = int.tryParse(_gramsController.text) ?? 0;
                                final next = (val + 1).clamp(0, 400);
                                _gramsController.text = next.toString();
                              },
                              icon: const Icon(Icons.add),
                              tooltip: '+1',
                            ),
                            IconButton(
                              onPressed: () {
                                final val = int.tryParse(_gramsController.text) ?? 0;
                                final next = (val - 1).clamp(0, 400);
                                _gramsController.text = next.toString();
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDateTime(context),
                            icon: const Icon(Icons.schedule),
                            label: Text(
                              '${_targetAt.toLocal()}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _showInCalendar,
                          onChanged: (v) => setState(() => _showInCalendar = v),
                        ),
                        const SizedBox(width: 4),
                        const Text('Show in calendar'),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _save(context),
                          icon: const Icon(Icons.check),
                          label: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
