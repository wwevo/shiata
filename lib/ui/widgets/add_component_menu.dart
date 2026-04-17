import 'package:flutter/material.dart';

/// Shared menu dialog for selecting which type of component to add.
/// 
/// Returns 'kind', 'product', 'recipe', or null if cancelled.
/// 
/// The enabledTypes parameter controls which options are shown.
/// This makes it easy to customize per editor (e.g., some may not support recipes yet).
/// 
/// Usage:
/// ```dart
/// final type = await showDialog<String>(
///   context: context,
///   builder: (ctx) => AddComponentMenu(
///     enabledTypes: {'kind', 'product'}, // Customize which types are available
///   ),
/// );
/// ```
class AddComponentMenu extends StatelessWidget {
  const AddComponentMenu({
    super.key,
    required this.enabledTypes,
  });

  /// Set of enabled component types: 'kind', 'product', 'recipe'
  final Set<String> enabledTypes;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Add component'),
      children: [
        if (enabledTypes.contains('kind'))
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('kind'),
            child: const ListTile(
              leading: Icon(Icons.category_outlined),
              title: Text('Add kind'),
            ),
          ),
        if (enabledTypes.contains('product'))
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('product'),
            child: const ListTile(
              leading: Icon(Icons.shopping_basket_outlined),
              title: Text('Add product'),
            ),
          ),
        if (enabledTypes.contains('recipe'))
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('recipe'),
            child: const ListTile(
              leading: Icon(Icons.restaurant_menu_outlined),
              title: Text('Add recipe'),
            ),
          ),
      ],
    );
  }
}
