import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widget_kind.dart';
import 'create_action.dart';

/// Holds all registered widget kinds and provides simple helpers.
class WidgetRegistry {
  WidgetRegistry(this._kinds);

  final Map<String, WidgetKind> _kinds;

  List<WidgetKind> get all => _kinds.values.toList(growable: false);

  WidgetKind? byId(String id) => _kinds[id];

  /// Aggregate all actions for a target date from all kinds.
  List<({WidgetKind kind, CreateAction action})> actionsForDate(
    BuildContext context,
    DateTime targetDate,
  ) {
    final items = <({WidgetKind kind, CreateAction action})>[];
    for (final kind in _kinds.values) {
      final acts = kind.createActions(context, targetDate);
      for (final a in acts) {
        items.add((kind: kind, action: a));
      }
    }
    // Order by priority desc, then label asc
    items.sort((a, b) {
      final p = b.action.priority.compareTo(a.action.priority);
      if (p != 0) return p;
      return a.action.label.compareTo(b.action.label);
    });
    return items;
  }
}

final widgetRegistryProvider = Provider<WidgetRegistry>((ref) {
  // The concrete kinds are provided from the app layer; for now this provider
  // will be overridden in main with the actual kinds.
  return WidgetRegistry(<String, WidgetKind>{});
});
