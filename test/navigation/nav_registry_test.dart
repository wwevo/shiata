import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/navigation/nav_models.dart';
import 'package:shiata/navigation/nav_registry.dart';
import 'package:shiata/ui/main_screen_providers.dart';
import 'package:shiata/ui/pages/database_page.dart';

void main() {
  group('NavRegistry Unit Tests', () {
    final customRegistry = NavRegistry([
      NavGroupItem(
        id: 'group_1',
        label: 'Group 1',
        icon: Icons.folder,
        children: [
          NavPageItem(
            id: 'child_page_1',
            label: 'Child Page 1',
            icon: Icons.description,
            selectionCategory: SelectionCategory.recipes,
            pageBuilder: (_, _) => const SizedBox(),
          ),
          NavActionItem(
            id: 'child_action_1',
            label: 'Child Action 1',
            icon: Icons.flash_on,
            onTrigger: (_, _) async {},
          ),
        ],
      ),
      NavPageItem(
        id: 'top_page_2',
        label: 'Top Page 2',
        icon: Icons.home,
        selectionCategory: SelectionCategory.products,
        pageBuilder: (_, _) => const SizedBox(),
      ),
      NavActionItem(
        id: 'top_action_3',
        label: 'Top Action 3',
        icon: Icons.star,
        onTrigger: (_, _) async {},
      ),
    ]);

    test('findPage returns top-level and nested pages', () {
      final childPage = customRegistry.findPage('child_page_1');
      expect(childPage, isNotNull);
      expect(childPage!.id, 'child_page_1');
      expect(childPage.label, 'Child Page 1');
      expect(childPage.selectionCategory, SelectionCategory.recipes);

      final topPage = customRegistry.findPage('top_page_2');
      expect(topPage, isNotNull);
      expect(topPage!.id, 'top_page_2');
      expect(topPage.label, 'Top Page 2');

      expect(customRegistry.findPage('unknown_id'), isNull);
      expect(customRegistry.findPage('group_1'), isNull);
      expect(customRegistry.findPage('top_action_3'), isNull);
    });

    test('findItem returns any NavItem by id', () {
      expect(customRegistry.findItem('group_1')?.label, 'Group 1');
      expect(customRegistry.findItem('child_page_1')?.label, 'Child Page 1');
      expect(customRegistry.findItem('child_action_1')?.label, 'Child Action 1');
      expect(customRegistry.findItem('top_page_2')?.label, 'Top Page 2');
      expect(customRegistry.findItem('top_action_3')?.label, 'Top Action 3');
      expect(customRegistry.findItem('non_existent'), isNull);
    });

    test('findTopLevelIndex resolves indices correctly', () {
      expect(customRegistry.findTopLevelIndex('child_page_1'), 0);
      expect(customRegistry.findTopLevelIndex('child_action_1'), 0);
      expect(customRegistry.findTopLevelIndex('group_1'), 0);
      expect(customRegistry.findTopLevelIndex('top_page_2'), 1);
      expect(customRegistry.findTopLevelIndex('top_action_3'), 2);
      expect(customRegistry.findTopLevelIndex('unknown'), 0);
    });

    test('navRegistryProvider contains default app navigation structure', () {
      final container = ProviderContainer();
      final registry = container.read(navRegistryProvider);

      expect(registry.findPage('active_week'), isNotNull);
      expect(registry.findPage('cookingaids'), isNotNull);
      expect(registry.findPage('recipes'), isNotNull);
      expect(registry.findPage('products'), isNotNull);
      expect(registry.findPage('kinds'), isNotNull);
      expect(registry.findPage('collections'), isNotNull);
      expect(registry.findPage('database'), isNotNull);
      expect(registry.findPage('database_admin'), isNotNull);

      // Top level indices
      expect(registry.findTopLevelIndex('active_week'), 0);
      expect(registry.findTopLevelIndex('cookingaids'), 0);
      expect(registry.findTopLevelIndex('recipes'), 1);
      expect(registry.findTopLevelIndex('products'), 1);
      expect(registry.findTopLevelIndex('kinds'), 1);
      expect(registry.findTopLevelIndex('collections'), 1);
      expect(registry.findTopLevelIndex('database'), 2);
      expect(registry.findTopLevelIndex('database_admin'), 2);
    });

    test('activeCategoryProvider resolves categories dynamically from registry', () {
      final container = ProviderContainer();

      container.read(currentSectionIdProvider.notifier).state = 'recipes';
      expect(container.read(activeCategoryProvider), SelectionCategory.recipes);

      container.read(currentSectionIdProvider.notifier).state = 'products';
      expect(container.read(activeCategoryProvider), SelectionCategory.products);

      container.read(currentSectionIdProvider.notifier).state = 'kinds';
      expect(container.read(activeCategoryProvider), SelectionCategory.kinds);

      container.read(currentSectionIdProvider.notifier).state = 'collections';
      expect(container.read(activeCategoryProvider), SelectionCategory.collections);

      container.read(currentSectionIdProvider.notifier).state = 'cookingaids';
      expect(container.read(activeCategoryProvider), SelectionCategory.cookingaids);

      // Database tab switching
      container.read(currentSectionIdProvider.notifier).state = 'database';
      container.read(databaseTabProvider.notifier).state = 0;
      expect(container.read(activeCategoryProvider), SelectionCategory.entries);

      container.read(databaseTabProvider.notifier).state = 1;
      expect(container.read(activeCategoryProvider), SelectionCategory.kinds);

      container.read(databaseTabProvider.notifier).state = 2;
      expect(container.read(activeCategoryProvider), SelectionCategory.products);

      container.read(databaseTabProvider.notifier).state = 3;
      expect(container.read(activeCategoryProvider), SelectionCategory.recipes);
    });

    test('NavPageItem resolveCategory respects categoryResolver and fallback', () {
      final staticItem = NavPageItem(
        id: 'test_static',
        label: 'Static',
        icon: Icons.star,
        selectionCategory: SelectionCategory.kinds,
        pageBuilder: (_, _) => const SizedBox(),
      );

      final customCategoryProvider = StateProvider<SelectionCategory>((_) => SelectionCategory.products);
      final dynamicItem = NavPageItem(
        id: 'test_dynamic',
        label: 'Dynamic',
        icon: Icons.star,
        categoryResolver: (ref) => ref.watch(customCategoryProvider),
        pageBuilder: (_, _) => const SizedBox(),
      );

      final defaultItem = NavPageItem(
        id: 'test_default',
        label: 'Default',
        icon: Icons.star,
        pageBuilder: (_, _) => const SizedBox(),
      );

      final container = ProviderContainer();

      expect(container.read(Provider((ref) => staticItem.resolveCategory(ref))), SelectionCategory.kinds);
      expect(container.read(Provider((ref) => dynamicItem.resolveCategory(ref))), SelectionCategory.products);
      expect(container.read(Provider((ref) => defaultItem.resolveCategory(ref))), SelectionCategory.entries);

      container.read(customCategoryProvider.notifier).state = SelectionCategory.recipes;
      expect(container.read(Provider((ref) => dynamicItem.resolveCategory(ref))), SelectionCategory.recipes);
    });
  });
}
