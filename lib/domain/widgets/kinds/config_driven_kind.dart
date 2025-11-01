import 'package:flutter/material.dart';

import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';
import '../../../ui/editors/generic_nutrient_editor.dart';

/// A metadata-driven kind for vitamins/minerals and other simple integer-based nutrients.
class ConfigDrivenKind extends WidgetKind {
  const ConfigDrivenKind({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.accentColor,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    this.defaultShowInCalendar = false,
    this.precision = 0,
  });

  @override
  final String id;

  @override
  final String displayName;

  @override
  final IconData icon;

  @override
  final Color accentColor;

  @override
  final String unit;

  @override
  final int precision;

  @override
  final int minValue;

  @override
  final int maxValue;

  @override
  final bool defaultShowInCalendar;

  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) {
    return [
      CreateAction(
        id: 'custom',
        label: 'Add $displayName',
        icon: Icons.add,
        priority: 10,
        color: accentColor,
        run: (ctx, date) async {
          final now = DateTime.now();
          final initial = DateTime(date.year, date.month, date.day, now.hour, now.minute);
          await Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => GenericNutrientEditorScreen(
                kind: this,
                initialTargetAt: initial,
              ),
            ),
          );
        },
      )
    ];
  }
}
