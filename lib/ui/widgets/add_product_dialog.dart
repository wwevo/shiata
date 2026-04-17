import 'package:flutter/material.dart';
import '../../data/repo/products_repository.dart';

/// Shared dialog for selecting a product from the available products list.
/// 
/// Returns the selected ProductDef, or null if cancelled.
/// 
/// Usage:
/// ```dart
/// final product = await showDialog<ProductDef?>(
///   context: context,
///   builder: (ctx) => AddProductDialog(products: await productsRepo.listProducts()),
/// );
/// ```
class AddProductDialog extends StatefulWidget {
  const AddProductDialog({
    super.key,
    required this.products,
  });

  final List<ProductDef> products;

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  ProductDef? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add product'),
      content: DropdownButton<ProductDef>(
        value: _selected,
        hint: const Text('Select product'),
        isExpanded: true,
        items: [
          for (final p in widget.products)
            DropdownMenuItem(value: p, child: Text(p.name)),
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
            final p = _selected;
            if (p == null) return;
            Navigator.of(context).pop(p);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
