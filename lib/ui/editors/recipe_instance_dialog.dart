import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/recipe_service.dart';
import '../../domain/widgets/registry.dart';
import '../../utils/formatters.dart';
import '../widgets/editor_dialog_actions.dart';

class RecipeInstantiateDialog extends ConsumerStatefulWidget {
  const RecipeInstantiateDialog({super.key, required this.recipeId, required this.initialTarget});
  final String recipeId;
  final DateTime initialTarget;
  @override
  ConsumerState<RecipeInstantiateDialog> createState() => RecipeInstantiateDialogState();
}

class RecipeInstantiateDialogState extends ConsumerState<RecipeInstantiateDialog> {
  // State variables
  String _recipeName = '';
  DateTime _targetAt = DateTime.now();
  bool _loading = true;
  List<dynamic> _components = const [];
  final Map<String, TextEditingController> _kindCtrls = {};
  final Map<String, TextEditingController> _productCtrls = {};

  @override
  void initState() {
    super.initState();
    _targetAt = widget.initialTarget;
    _load();
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

  Future<void> _load() async {
    final repo = ref.read(recipesRepositoryProvider);
    if (repo != null) {
      final def = await repo.getRecipe(widget.recipeId);
      final comps = await repo.getComponents(widget.recipeId);
      if (mounted) {
        setState(() {
          _recipeName = def?.name ?? '';
          _components = comps;
          _loading = false;
        });
      }
      // Initialize controllers
      for (final c in comps) {
        final typeStr = c.type.toString();
        if (typeStr.endsWith('kind')) {
          _kindCtrls[c.compId] = TextEditingController(text: fmtDouble(c.amount ?? 0.0));
        } else {
          _productCtrls[c.compId] = TextEditingController(text: (c.grams ?? 0).toString());
        }
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_targetAt),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (time == null) return;
    setState(() {
      _targetAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save(BuildContext context, {bool closeAfter = false}) async {
    final svc = ref.read(recipeServiceProvider);
    if (svc == null) return;
    final kindOverrides = <String, double>{};
    final productOverrides = <String, int>{};
    _kindCtrls.forEach((k, v) {
      final d = double.tryParse(v.text.trim());
      if (d != null) kindOverrides[k] = d;
    });
    _productCtrls.forEach((k, v) {
      final g = int.tryParse(v.text.trim());
      if (g != null) productOverrides[k] = g;
    });
    await svc.createRecipeEntry(
      recipeId: widget.recipeId,
      targetAtLocal: _targetAt,
      kindOverrides: kindOverrides.isEmpty ? null : kindOverrides,
      productGramOverrides: productOverrides.isEmpty ? null : productOverrides,
      showParentInCalendar: true,
    );
    if (closeAfter && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);
    return AlertDialog(
      title: Text('Instantiate: ${_recipeName.isEmpty ? widget.recipeId : _recipeName}'),
      content: _loading
          ? const SizedBox(width: 480, height: 120, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDateTime(context),
                      icon: const Icon(Icons.schedule),
                      label: Text('${_targetAt.toLocal()}'),
                    ),
                    const SizedBox(height: 12),
                    if (_components.isEmpty)
                      const Text('No components in this recipe yet')
                    else ...[
                      for (final c in _components)
                        Builder(builder: (ctx) {
                          final typeStr = c.type.toString();
                          if (typeStr.endsWith('kind')) {
                            final k = registry.byId(c.compId);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextField(
                                controller: _kindCtrls[c.compId],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: InputDecoration(
                                  labelText: '${k?.displayName ?? c.compId} (${k?.unit ?? ''})',
                                ),
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextField(
                                controller: _productCtrls[c.compId],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Product: ${c.compId} (grams)',
                                ),
                              ),
                            );
                          }
                        }),
                    ],
                  ],
                ),
              ),
            ),
      actions: editorDialogActions(
        context: context,
        onSave: ({required closeAfter}) => _save(context, closeAfter: closeAfter),
      ),
    );
  }
}
