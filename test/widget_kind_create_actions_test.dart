import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/data/repo/collections_repository.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/domain/widgets/collections/db_backed_collection.dart';
import 'package:shiata/domain/widgets/kinds/db_backed_kind.dart';
import 'package:shiata/domain/widgets/products/db_backed_product.dart';
import 'package:shiata/domain/widgets/recipes/db_backed_recipe.dart';
import 'package:shiata/domain/widgets/widget_kind.dart';

void main() {
  testWidgets('create actions use each adapter icon and accent color', (
    tester,
  ) async {
    const storedColor = 0xFF123456;

    IconData iconResolver(String? iconName, IconData fallback) {
      return iconName == 'custom' ? Icons.star : fallback;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            for (final values in [
              (icon: 'custom', color: storedColor),
              (icon: null, color: null),
              (icon: 'unknown', color: null),
            ]) {
              for (final adapter in _adapters(
                icon: values.icon,
                color: values.color,
                iconResolver: iconResolver,
              )) {
                final action = adapter
                    .createActions(context, DateTime(2026, 1, 1))
                    .single;

                expect(action.icon, adapter.icon);
                expect(action.color, adapter.accentColor);
                expect(action.icon, isNot(Icons.add));
              }
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}

List<WidgetKind> _adapters({
  required String? icon,
  required int? color,
  required IconData Function(String? iconName, IconData fallback) iconResolver,
}) {
  return [
    DbBackedKind(
      KindDef(
        id: 'kind',
        name: 'Kind',
        unit: 'g',
        min: 0,
        max: 100,
        icon: icon,
        color: color,
      ),
      iconResolver: iconResolver,
    ),
    DbBackedProduct(
      ProductDef(
        id: 'product',
        name: 'Product',
        createdAt: 0,
        updatedAt: 0,
        icon: icon,
        color: color,
      ),
      iconResolver: iconResolver,
    ),
    DbBackedRecipe(
      RecipeDef(
        id: 'recipe',
        name: 'Recipe',
        createdAt: 0,
        updatedAt: 0,
        icon: icon,
        color: color,
      ),
      iconResolver: iconResolver,
    ),
    DbBackedCollection(
      CollectionDef(
        id: 'collection',
        name: 'Collection',
        createdAt: 0,
        updatedAt: 0,
        icon: icon,
        color: color,
      ),
      iconResolver: iconResolver,
    ),
  ];
}
