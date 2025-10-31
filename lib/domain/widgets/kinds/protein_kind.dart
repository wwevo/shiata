import 'package:flutter/material.dart';

import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';
import '../../../ui/editors/protein_editor.dart';

class ProteinKind extends WidgetKind {
  const ProteinKind();

  @override
  String get id => 'protein';

  @override
  String get displayName => 'Protein';

  @override
  IconData get icon => Icons.fitness_center;

  @override
  Color get accentColor => Colors.indigo;

  @override
  String get unit => 'g';

  @override
  int get minValue => 0;

  @override
  int get maxValue => 300;

  @override
  bool get defaultShowInCalendar => false;

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
          final now = DateTime.now();
          final initial = DateTime(date.year, date.month, date.day, now.hour, now.minute);
          await Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => ProteinEditorScreen(initialTargetAt: initial)),
          );
        },
      ),
    ];
  }
}
