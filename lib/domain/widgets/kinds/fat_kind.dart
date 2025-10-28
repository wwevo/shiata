import 'package:flutter/material.dart';

import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';
import '../../../ui/editors/fat_editor.dart';

class FatKind extends WidgetKind {
  const FatKind();

  @override
  String get id => 'fat';

  @override
  String get displayName => 'Fat';

  @override
  IconData get icon => Icons.opacity; // droplet-like

  @override
  Color get accentColor => Colors.amber; // yellow accent

  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) {
    return [
      CreateAction(
        id: 'custom',
        label: 'Custom grams',
        icon: Icons.edit,
        priority: 10,
        color: accentColor,
        run: (ctx, date) async {
          await Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => FatEditorScreen()),
          );
        },
      ),
    ];
  }
}
