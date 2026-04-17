import 'package:flutter/material.dart';
import '../../data/repo/recipes_repository.dart';

/// Shared dialog for selecting a recipe from the available recipes list.
/// 
/// Returns the selected RecipeDef, or null if cancelled.
/// 
/// Usage:
/// ```dart
/// final recipe = await showDialog<RecipeDef?>(
///   context: context,
///   builder: (ctx) => AddRecipeDialog(recipes: await recipesRepo.listRecipes()),
/// );
/// ```
class AddRecipeDialog extends StatefulWidget {
  const AddRecipeDialog({
    super.key,
    required this.recipes,
  });

  final List<RecipeDef> recipes;

  @override
  State<AddRecipeDialog> createState() => _AddRecipeDialogState();
}

class _AddRecipeDialogState extends State<AddRecipeDialog> {
  RecipeDef? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add recipe'),
      content: DropdownButton<RecipeDef>(
        value: _selected,
        hint: const Text('Select recipe'),
        isExpanded: true,
        items: [
          for (final r in widget.recipes)
            DropdownMenuItem(value: r, child: Text(r.name)),
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
            final r = _selected;
            if (r == null) return;
            Navigator.of(context).pop(r);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
