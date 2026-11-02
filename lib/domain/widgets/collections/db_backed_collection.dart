import 'package:flutter/material.dart';

import '../../../data/repo/collections_repository.dart';
import '../../../ui/editors/collection_instance_dialog.dart';
import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';

/// Adapter to expose a DB-stored collection as a `WidgetKind`.
class DbBackedCollection extends WidgetKind {
  const DbBackedCollection(this.def, {required this.iconResolver});

  final CollectionDef def;

  /// Resolves a Material `IconData` from a stored icon name (nullable).
  /// Fallback will be used if resolution fails or icon is null.
  final IconData Function(String? iconName, IconData fallback) iconResolver;

  @override
  String get id => 'collection:${def.id}';

  @override
  String get displayName => def.name;

  @override
  IconData get icon => iconResolver(def.icon, Icons.layers);

  @override
  Color get accentColor => Color(def.color ?? 0xFF3F51B5); // default Indigo 500

  @override
  String get unit => 'serving';

  @override
  int get minValue => 1;

  @override
  int get maxValue => 100;

  @override
  bool get defaultShowInCalendar => false;

  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) {
    return [
      CreateAction(
        id: 'add_collection',
        label: 'Add $displayName',
        icon: Icons.add,
        priority: 5,
        color: accentColor,
        run: (ctx, date) async {
          await showDialog(
            context: ctx,
            builder: (dialogContext) => CollectionInstantiateDialog(
              collectionId: def.id,
              initialTarget: date,
            ),
          );
        },
      ),
    ];
  }
}
