import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/editors/collection_template_editor_dialog.dart';
import '../../ui/editors/kind_template_editor_dialog.dart';
import '../../ui/editors/product_template_editor_dialog.dart';
import '../../ui/editors/recipe_template_editor_dialog.dart';
import 'create_action.dart';
import 'registry.dart';

/// Configuration for adding elements on a specific page/section.
class PageAddConfig {
  final String pageId;
  final String title;
  final bool showTimePicker;
  final List<CreateAction> Function(
    BuildContext context,
    WidgetRef ref,
    DateTime targetDateTime,
  ) actionsBuilder;

  const PageAddConfig({
    required this.pageId,
    this.title = 'Add',
    this.showTimePicker = false,
    required this.actionsBuilder,
  });
}

/// Registry storing add-action capabilities and configurations for app pages.
class AddRegistry {
  final Map<String, PageAddConfig> _configs;

  const AddRegistry(this._configs);

  /// Look up configuration for a given page ID.
  PageAddConfig? getConfig(String pageId) => _configs[pageId];

  /// Check if a page has an add action registered.
  bool hasAddAction(String pageId) => _configs.containsKey(pageId);

  /// All registered page configs.
  List<PageAddConfig> get all => _configs.values.toList(growable: false);
}

/// Provider for the global [AddRegistry].
final addRegistryProvider = Provider<AddRegistry>((ref) {
  return AddRegistry({
    'active_week': PageAddConfig(
      pageId: 'active_week',
      title: 'Add entry',
      showTimePicker: true,
      actionsBuilder: (context, ref, targetDateTime) {
        final registry = ref.read(widgetRegistryProvider);
        final items = registry.actionsForDate(context, targetDateTime);
        return items.map((e) => e.action).toList();
      },
    ),
    'recipes': PageAddConfig(
      pageId: 'recipes',
      title: 'Add recipe',
      showTimePicker: false,
      actionsBuilder: (context, ref, targetDateTime) {
        return [
          CreateAction(
            id: 'add_recipe',
            label: 'Add recipe',
            icon: Icons.restaurant_menu,
            color: const Color(0xFFFF9800),
            priority: 10,
            run: (ctx, d) async {
              final repo = ref.read(recipesRepositoryProvider);
              if (repo != null) {
                await showDialog(
                  context: ctx,
                  builder: (_) => const RecipeEditorDialog(
                    existing: null,
                  ),
                );
              }
            },
          ),
        ];
      },
    ),
    'products': PageAddConfig(
      pageId: 'products',
      title: 'Add product',
      showTimePicker: false,
      actionsBuilder: (context, ref, targetDateTime) {
        return [
          CreateAction(
            id: 'add_product',
            label: 'Add product',
            icon: Icons.shopping_basket,
            color: const Color(0xFF4CAF50),
            priority: 10,
            run: (ctx, d) async {
              final repo = ref.read(productsRepositoryProvider);
              if (repo != null) {
                await showDialog(
                  context: ctx,
                  builder: (_) => const ProductTemplateEditorDialog(
                    existing: null,
                  ),
                );
              }
            },
          ),
        ];
      },
    ),
    'kinds': PageAddConfig(
      pageId: 'kinds',
      title: 'Add kind',
      showTimePicker: false,
      actionsBuilder: (context, ref, targetDateTime) {
        return [
          CreateAction(
            id: 'add_kind',
            label: 'Add kind',
            icon: Icons.category,
            color: const Color(0xFF607D8B),
            priority: 10,
            run: (ctx, d) async {
              await showDialog(
                context: ctx,
                builder: (c) => KindTemplateEditorDialog(),
              );
            },
          ),
        ];
      },
    ),
    'collections': PageAddConfig(
      pageId: 'collections',
      title: 'Add collection',
      showTimePicker: false,
      actionsBuilder: (context, ref, targetDateTime) {
        return [
          CreateAction(
            id: 'add_collection',
            label: 'Add collection',
            icon: Icons.collections,
            color: const Color(0xFF3F51B5),
            priority: 10,
            run: (ctx, d) async {
              final repo = ref.read(collectionsRepositoryProvider);
              if (repo != null) {
                await showDialog(
                  context: ctx,
                  builder: (_) => const CollectionEditorDialog(
                    existing: null,
                  ),
                );
              }
            },
          ),
        ];
      },
    ),
    'cookingaids': PageAddConfig(
      pageId: 'cookingaids',
      title: 'Add cooking aid',
      showTimePicker: false,
      actionsBuilder: (context, ref, targetDateTime) {
        return [
          CreateAction(
            id: 'add_cooking_aid',
            label: 'Add cooking aid',
            icon: Icons.shopping_basket_outlined,
            color: const Color(0xFF009688),
            priority: 10,
            run: (ctx, d) async {
              await showDialog(
                context: ctx,
                builder: (c) => AlertDialog(
                  title: const Text('Add Cooking Aid'),
                  content: const Text('Cooking Aid feature coming soon.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ];
      },
    ),
  });
});
