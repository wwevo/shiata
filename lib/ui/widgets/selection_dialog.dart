import 'package:flutter/material.dart';

/// Generic dialog for selecting an item from a list.
///
/// Returns the selected item of type [T], or `null` if cancelled.
///
/// Usage:
/// ```dart
/// final selected = await showDialog<ProductDef?>(
///   context: context,
///   builder: (ctx) => SelectionDialog<ProductDef>(
///     title: 'Add product',
///     hint: 'Select product',
///     items: products,
///     itemLabel: (p) => p.name,
///   ),
/// );
/// ```
class SelectionDialog<T> extends StatefulWidget {
  const SelectionDialog({
    super.key,
    required this.title,
    required this.items,
    required this.itemLabel,
    this.hint = 'Select item',
    this.confirmLabel = 'Add',
  });

  final String title;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String hint;
  final String confirmLabel;

  @override
  State<SelectionDialog<T>> createState() => _SelectionDialogState<T>();
}

class _SelectionDialogState<T> extends State<SelectionDialog<T>> {
  T? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: DropdownButton<T>(
        value: _selected,
        hint: Text(widget.hint),
        isExpanded: true,
        items: [
          for (final item in widget.items)
            DropdownMenuItem(
              value: item,
              child: Text(widget.itemLabel(item)),
            ),
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
            final item = _selected;
            if (item == null) return;
            Navigator.of(context).pop(item);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
