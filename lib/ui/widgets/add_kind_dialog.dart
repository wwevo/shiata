import 'package:flutter/material.dart';
import '../../domain/widgets/widget_kind.dart';

class AddKindDialog extends StatefulWidget {
  const AddKindDialog({super.key, required this.kinds});

  final List<WidgetKind> kinds;

  @override
  State<AddKindDialog> createState() => _AddKindDialogState();
}

class _AddKindDialogState extends State<AddKindDialog> {
  WidgetKind? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add kind'),
      content: DropdownButton<WidgetKind>(
        value: _selected,
        hint: const Text('Select kind'),
        isExpanded: true,
        items: [
          for (final k in widget.kinds)
            DropdownMenuItem(value: k, child: Text(k.displayName)),
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
            final k = _selected;
            if (k == null) return;
            Navigator.of(context).pop(k);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
