import 'package:flutter/material.dart';

import '../../../data/repo/kinds_repository.dart';
import '../../../ui/editors/kind_instance_editor_dialog.dart';
import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';

/// Adapter to expose a DB-stored kind as a `WidgetKind`.
class DbBackedKind extends WidgetKind {
  const DbBackedKind(this.def, {required this.iconResolver});

  final KindDef def;

  /// Resolves a Material `IconData` from a stored icon name (nullable).
  /// Fallback will be used if resolution fails or icon is null.
  final IconData Function(String? iconName, IconData fallback) iconResolver;

  @override
  String get id => def.id;

  @override
  String get displayName => def.name;

  @override
  IconData get icon => iconResolver(def.icon, Icons.category);

  @override
  Color get accentColor => Color(def.color ?? 0xFF607D8B); // default Blue Grey 500

  @override
  String get unit => def.unit;

  @override
  int get minValue => def.min;

  @override
  int get maxValue => def.max;

  @override
  bool get defaultShowInCalendar => def.defaultShowInCalendar;

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
/*
          await Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => KindInstanceEditorScreen(
                kind: this,
                initialTargetAt: initial,
              ),
            ),
          );
*/
          await showDialog(
            context: context,
            builder: (_) =>
                KindInstanceEditorDialog(
                  kind: this,
                  initialTargetAt: initial,
                ),
          );
        },
      )
    ];
  }
}
