import 'package:flutter/material.dart';

/// Describes a widget-provided create action shown in the Create Action Sheet (CAS).
class CreateAction {
  const CreateAction({
    required this.id,
    required this.label,
    required this.icon,
    this.color,
    this.priority = 0,
    required this.run,
  });

  /// Stable id unique within the owning widget kind.
  final String id;

  /// Short label (e.g., "Custom grams").
  final String label;

  /// Icon glyph to render in a colored circle.
  final IconData icon;

  /// Optional accent color (defaults to the widget kind's accentColor).
  final Color? color;

  /// Larger priority shows earlier; ties resolved alphabetically by label.
  final int priority;

  /// Executes the action (e.g., navigate to create editor, or quick-create then open edit).
  final Future<void> Function(BuildContext context, DateTime targetDate) run;
}
