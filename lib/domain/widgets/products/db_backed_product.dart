import 'package:flutter/material.dart';

import '../../../data/repo/products_repository.dart';
import '../../../ui/editors/product_instance_editor_dialog.dart';
import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';

/// Adapter to expose a DB-stored product as a `WidgetKind`.
class DbBackedProduct extends WidgetKind {
  const DbBackedProduct(this.def, {required this.iconResolver});

  final ProductDef def;

  /// Resolves a Material `IconData` from a stored icon name (nullable).
  /// Fallback will be used if resolution fails or icon is null.
  final IconData Function(String? iconName, IconData fallback) iconResolver;

  @override
  String get id => 'product:${def.id}';

  @override
  String get displayName => def.name;

  @override
  IconData get icon => iconResolver(def.icon, Icons.shopping_basket);

  @override
  Color get accentColor => Color(def.color ?? 0xFF4CAF50); // default Green 500

  @override
  String get unit => 'g';

  @override
  int get minValue => 0;

  @override
  int get maxValue => 100000; // 100kg in grams

  @override
  bool get defaultShowInCalendar => false;

  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) {
    return [
      CreateAction(
        id: 'add_100g',
        label: 'Add $displayName',
        icon: Icons.add,
        priority: 5,
        color: accentColor,
        run: (ctx, date) async {
          final now = DateTime.now();
          final initial = DateTime(
            date.year,
            date.month,
            date.day,
            now.hour,
            now.minute,
          );
          /*          await Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => ProductEditorScreen(
                productId: def.id,
                initialTargetAt: initial,
                defaultGrams: 100, // Default 100g
              ),
            ),
          );*/
          await showDialog(
            context: ctx,
            builder: (_) => ProductEditorDialog(
              productId: def.id,
              initialTargetAt: initial,
              defaultGrams: 100, // Default 100g
            ),
          );
        },
      ),
    ];
  }
}
