import 'package:flutter/material.dart';

import '../../domain/widgets/create_action.dart';
import '../../domain/widgets/widget_kind.dart';

class AdHocKind extends WidgetKind {
  const AdHocKind({required this.id, required this.displayName, required this.icon, required this.accentColor, required this.unit, required this.minValue, required this.maxValue, required this.defaultShowInCalendar});
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
  final int minValue;
  @override
  final int maxValue;
  @override
  final bool defaultShowInCalendar;
  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) => const [];
}
