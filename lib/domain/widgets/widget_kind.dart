import 'package:flutter/material.dart';

import 'create_action.dart';

/// Base contract for a widget kind (e.g., Protein, Fat, Smoothie, etc.).
abstract class WidgetKind {
  const WidgetKind();

  /// Stable identifier used in storage/routing (e.g., "protein").
  String get id;

  /// Human-friendly name (e.g., "Protein").
  String get displayName;

  /// Icon to represent this widget kind.
  IconData get icon;

  /// Accent color used for calendar dots, action glyphs, etc.
  Color get accentColor;

  /// Canonical unit for this kind's amount (e.g., 'g', 'mg', 'ug').
  String get unit;

  /// Inclusive min allowed integer value for the amount field (stored scale).
  int get minValue;

  /// Inclusive max allowed integer value for the amount field (stored scale).
  int get maxValue;

  /// Whether newly created entries for this kind should default to show in calendar.
  bool get defaultShowInCalendar;

  /// Returns the list of create actions to show for the given target date.
  List<CreateAction> createActions(BuildContext context, DateTime targetDate);
}
