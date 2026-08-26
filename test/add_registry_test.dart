import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/domain/widgets/add_registry.dart';

void main() {
  group('AddRegistry Tests', () {
    test('registers all standard pages with appropriate configuration', () {
      final ref = ProviderContainer();
      final registry = ref.read(addRegistryProvider);

      expect(registry.hasAddAction('active_week'), isTrue);
      expect(registry.hasAddAction('recipes'), isTrue);
      expect(registry.hasAddAction('products'), isTrue);
      expect(registry.hasAddAction('kinds'), isTrue);
      expect(registry.hasAddAction('collections'), isTrue);
      expect(registry.hasAddAction('cookingaids'), isTrue);
      expect(registry.hasAddAction('non_existent'), isFalse);

      final activeWeekConfig = registry.getConfig('active_week')!;
      expect(activeWeekConfig.showTimePicker, isTrue);
      expect(activeWeekConfig.title, 'Add entry');

      final recipesConfig = registry.getConfig('recipes')!;
      expect(recipesConfig.showTimePicker, isFalse);
      expect(recipesConfig.title, 'Add recipe');

      final productsConfig = registry.getConfig('products')!;
      expect(productsConfig.showTimePicker, isFalse);
      expect(productsConfig.title, 'Add product');

      final kindsConfig = registry.getConfig('kinds')!;
      expect(kindsConfig.showTimePicker, isFalse);
      expect(kindsConfig.title, 'Add kind');

      final collectionsConfig = registry.getConfig('collections')!;
      expect(collectionsConfig.showTimePicker, isFalse);
      expect(collectionsConfig.title, 'Add collection');
    });

    testWidgets('actionsBuilder builds respective action items', (tester) async {
      late BuildContext buildContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  buildContext = ctx;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      final element = tester.element(find.byType(SizedBox));
      final container = ProviderScope.containerOf(element);
      final registry = container.read(addRegistryProvider);

      final recipeConfig = registry.getConfig('recipes')!;
      final recipeActions = recipeConfig.actionsBuilder(
        buildContext,
        ConsumerStatefulWidgetRefMock(container),
        DateTime(2026, 8, 26, 12, 0),
      );
      expect(recipeActions.length, 1);
      expect(recipeActions.first.id, 'add_recipe');
      expect(recipeActions.first.label, 'Add recipe');

      final productConfig = registry.getConfig('products')!;
      final productActions = productConfig.actionsBuilder(
        buildContext,
        ConsumerStatefulWidgetRefMock(container),
        DateTime(2026, 8, 26, 12, 0),
      );
      expect(productActions.length, 1);
      expect(productActions.first.id, 'add_product');
      expect(productActions.first.label, 'Add product');

      final kindConfig = registry.getConfig('kinds')!;
      final kindActions = kindConfig.actionsBuilder(
        buildContext,
        ConsumerStatefulWidgetRefMock(container),
        DateTime(2026, 8, 26, 12, 0),
      );
      expect(kindActions.length, 1);
      expect(kindActions.first.id, 'add_kind');
      expect(kindActions.first.label, 'Add kind');

      final collectionsConfig = registry.getConfig('collections')!;
      final collectionActions = collectionsConfig.actionsBuilder(
        buildContext,
        ConsumerStatefulWidgetRefMock(container),
        DateTime(2026, 8, 26, 12, 0),
      );
      expect(collectionActions.length, 1);
      expect(collectionActions.first.id, 'add_collection');
      expect(collectionActions.first.label, 'Add collection');
    });
  });
}

class ConsumerStatefulWidgetRefMock implements WidgetRef {
  final ProviderContainer _container;
  ConsumerStatefulWidgetRefMock(this._container);

  @override
  BuildContext get context => throw UnimplementedError();

  @override
  bool exists(ProviderBase<Object?> provider) => _container.exists(provider);

  @override
  void invalidate(ProviderOrFamily provider) => _container.invalidate(provider);

  @override
  void listen<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => _container.listen(provider, listener, onError: onError);

  @override
  ProviderSubscription<T> listenManual<T>(
    ProviderListenable<T> provider,
    void Function(T? previous, T next) listener, {
    void Function(Object error, StackTrace stackTrace)? onError,
    bool fireImmediately = false,
  }) => _container.listen(provider, listener, onError: onError, fireImmediately: fireImmediately);

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  T refresh<T>(Refreshable<T> provider) => _container.refresh(provider);

  @override
  T watch<T>(ProviderListenable<T> provider) => _container.read(provider);
}
