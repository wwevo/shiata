import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widget_kind.dart';
import 'create_action.dart';
import '../../data/providers.dart';
import 'kinds/db_backed_kind.dart';
import '../../data/repo/kinds_repository.dart';

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
  final kindsValue = ref.watch(kindsListProvider);

  IconData resolveIcon(String? name, IconData fallback) {
    switch (name) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'opacity':
        return Icons.opacity;
      case 'rice_bowl':
        return Icons.rice_bowl;
      case 'battery_charging_full':
        return Icons.battery_charging_full;
      case 'blur_on':
        return Icons.blur_on;
      case 'bolt':
        return Icons.bolt;
      case 'circle':
        return Icons.circle;
      case 'hexagon':
        return Icons.hexagon; // may not exist on older SDKs
      case 'science':
        return Icons.science;
      case 'visibility':
        return Icons.visibility;
      case 'medical_information':
        return Icons.medical_information;
      case 'local_florist':
        return Icons.local_florist;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'eco':
        return Icons.eco;
      case 'grass':
        return Icons.grass;
      default:
        return fallback;
    }
  }

  final kinds = kindsValue.maybeWhen(
    data: (list) => list,
    orElse: () => const <KindDef>[],
  );

  final map = <String, WidgetKind>{};
  for (final k in kinds) {
    map[k.id] = DbBackedKind(k, iconResolver: resolveIcon);
  }
  return WidgetRegistry(map);
});
