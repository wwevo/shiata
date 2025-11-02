import 'package:flutter/material.dart';

import '../../widgets/create_action.dart';
import '../../widgets/widget_kind.dart';
import '../../../data/repo/recipes_repository.dart';
import '../../../ui/dialogs/recipe_instantiate_dialog.dart';

/// Adapter to expose a DB-stored recipe as a `WidgetKind`.
class DbBackedRecipe extends WidgetKind {
  const DbBackedRecipe(this.def, {required this.iconResolver});

  final RecipeDef def;

  /// Resolves a Material `IconData` from a stored icon name (nullable).
  /// Fallback will be used if resolution fails or icon is null.
  final IconData Function(String? iconName, IconData fallback) iconResolver;

  @override
  String get id => 'recipe:${def.id}';

  @override
  String get displayName => def.name;

  @override
  IconData get icon => iconResolver(def.icon, Icons.restaurant_menu);

  @override
  Color get accentColor => Color(def.color ?? 0xFFFF9800); // default Orange 500

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
        id: 'add_recipe',
        label: 'Add $displayName',
        icon: Icons.add,
        priority: 5,
        color: accentColor,
        run: (ctx, date) async {
          await showDialog(
            context: ctx,
            builder: (dialogContext) => RecipeInstantiateDialog(
              recipeId: def.id,
              // recipeName: def.name,
              initialTarget: date,
            ),
          );
        },
      )
    ];
  }
}