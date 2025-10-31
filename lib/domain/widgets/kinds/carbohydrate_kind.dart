import 'package:flutter/material.dart';

import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';
import '../../../ui/editors/carbohydrate_editor.dart';

class CarbohydrateKind extends WidgetKind {
  const CarbohydrateKind();

  @override
  String get id => 'carbohydrate';

  @override
  String get displayName => 'Carbohydrate';

  @override
  IconData get icon => Icons.rice_bowl; // represents carbs/grains

  @override
  Color get accentColor => Colors.red; // red accent as requested

  @override
  String get unit => 'g';

  @override
  int get minValue => 0;

  @override
  int get maxValue => 400;

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
            MaterialPageRoute(builder: (_) => CarbohydrateEditorScreen(initialTargetAt: initial)),
          );
        },
      ),
    ];
  }
}
