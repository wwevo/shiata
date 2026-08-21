import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/recipe_service.dart';
import '../../domain/widgets/registry.dart';
import '../../utils/formatters.dart';
import 'editor_form_support.dart';

class RecipeInstantiateDialog extends ConsumerStatefulWidget {
  const RecipeInstantiateDialog({
    super.key,
    this.entryId,
    this.recipeId,
    this.initialTarget,
  });

  final String? entryId; // if present → edit existing recipe instance
  final String? recipeId; // required for create, optional for edit
  final DateTime? initialTarget; // required for create, optional for edit
  @override
  ConsumerState<RecipeInstantiateDialog> createState() =>
      RecipeInstantiateDialogState();
}

class RecipeInstantiateDialogState
    extends ConsumerState<RecipeInstantiateDialog> with EditorDialogShell {
  // State variables
  String? _recipeId;
  String _recipeName = '';
  DateTime _targetAt = DateTime.now();
  bool _isStatic = false;
  bool _showInCalendar = true;
  List<dynamic> _components = const [];
  final Map<String, TextEditingController> _kindCtrls = {};
  final Map<String, TextEditingController> _productCtrls = {};

  @override
  void initState() {
    super.initState();
    loading = true;
    _recipeId = widget.recipeId;
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
    final recipesRepo = ref.read(recipesRepositoryProvider);
    if (entries == null || recipesRepo == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final entry = await entries.getById(widget.entryId!);
    if (entry != null) {
      _recipeId = entry.recipeId;
      try {
        final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
        _recipeName = payload['name'] as String? ?? '';
      } catch (_) {}
      _targetAt = DateTime.fromMillisecondsSinceEpoch(
        entry.targetAt,
        isUtc: true,
      ).toLocal();
      _isStatic = entry.isStatic;
      _showInCalendar = entry.showInCalendar;

      // Load children and populate controllers with their values
      if (_recipeId != null) {
        final children = await entries.listChildrenOfParent(widget.entryId!);
        final comps = await recipesRepo.getComponents(_recipeId!);

        // Clear old controllers
        for (final ctrl in _kindCtrls.values) {
          ctrl.dispose();
        }
        for (final ctrl in _productCtrls.values) {
          ctrl.dispose();
        }
        _kindCtrls.clear();
        _productCtrls.clear();

        // Initialize controllers with current values from children
        for (final c in comps) {
          final typeStr = c.type.toString();
          if (typeStr.endsWith('kind')) {
            // Find the child entry for this kind
            final childEntry = children
                .where((e) => e.widgetKind == c.compId)
                .firstOrNull;
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
            // Find the product child (it's a parent entry with widgetKind == 'product')
            final productChild = children
                .where(
                  (e) => e.widgetKind == 'product' && e.productId == c.compId,
                )
                .firstOrNull;
            int currentGrams = c.grams ?? 0;
            if (productChild != null) {
              currentGrams = productChild.productGrams ?? currentGrams;
            }
            _productCtrls[c.compId] = TextEditingController(
              text: currentGrams.toString(),
            );
          }
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
    final repo = ref.read(recipesRepositoryProvider);
    if (repo != null && _recipeId != null) {
      final def = await repo.getRecipe(_recipeId!);
      final comps = await repo.getComponents(_recipeId!);
      if (mounted) {
        setState(() {
          _recipeName = def?.name ?? '';
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

      // Initialize controllers with template defaults
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
      }
    } else {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handlePickDateTime(BuildContext context) async {
    final picked = await pickDateTime(context, _targetAt);
    if (picked != null) {
      setState(() => _targetAt = picked);
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
            'Do you want to reset all values to the recipe template defaults?\n\n'
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

  Future<void> _onSave({required bool closeAfter}) async {
    await safeSave(
      closeAfter: closeAfter,
      onSave: () async {
        final svc = ref.read(recipeServiceProvider);
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
          // Edit existing recipe instance
          await svc.updateRecipeInstance(
            parentEntryId: widget.entryId!,
            targetAtLocal: _targetAt,
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
                  'Updated ${_recipeName.isEmpty ? 'Recipe' : _recipeName}',
                ),
              ),
            );
          }
        } else {
          // Create new recipe instance
          if (_recipeId == null) {
            throw ArgumentError('No recipe selected');
          }
          await svc.createRecipeEntry(
            recipeId: _recipeId!,
            targetAtLocal: _targetAt,
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
                  'Added ${_recipeName.isEmpty ? 'Recipe' : _recipeName}',
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
          ? 'Edit ${_recipeName.isEmpty ? 'recipe' : _recipeName}'
          : 'Instantiate ${_recipeName.isEmpty ? _recipeId ?? 'recipe' : _recipeName}',
      onSave: ({required closeAfter}) => _onSave(closeAfter: closeAfter),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            title: const Text(
              'Static (don\'t update if recipe template changes)',
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
              child: Center(child: Text('No components in this recipe yet')),
            )
          else ...[
            for (final c in _components)
              Builder(
                builder: (ctx) {
                  final typeStr = c.type.toString();
                  if (typeStr.endsWith('kind')) {
                    final k = registry.byId(c.compId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: _kindCtrls[c.compId],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${k?.displayName ?? c.compId} (${k?.unit ?? ''})',
                        ),
                        validator: ValidationRules.nonNegativeAmount,
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextFormField(
                        controller: _productCtrls[c.compId],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Product: ${c.compId} (grams)',
                        ),
                        validator: ValidationRules.positiveGrams,
                      ),
                    );
                  }
                },
              ),
          ],
        ],
      ),
    );
  }
}
