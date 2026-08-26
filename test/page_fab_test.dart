import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/data/providers.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/ui/pages/collections_page.dart';
import 'package:shiata/ui/pages/cooking_aid_page.dart';
import 'package:shiata/ui/pages/kinds_page.dart';
import 'package:shiata/ui/pages/products_page.dart';
import 'package:shiata/ui/pages/recipes_page.dart';
import 'package:shiata/ui/widgets/add_floating_action_button.dart';

void main() {
  group('Page FAB Integration Tests', () {
    testWidgets('RecipesPage has Floating Action Button and no plus button in AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipesListProvider.overrideWith((ref) => Stream.value(<RecipeDef>[])),
          ],
          child: const MaterialApp(
            home: RecipesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check FAB is present
      expect(find.byType(AppAddFloatingActionButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Check AppBar does NOT have IconButton with add icon
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final appBarIconButtons = find.descendant(of: appBarFinder, matching: find.byType(IconButton));
      expect(appBarIconButtons, findsNothing);

      // Tap FAB to open action sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add recipe'), findsWidgets);
    });

    testWidgets('ProductTemplatesPage has Floating Action Button and no plus button in AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productsListProvider.overrideWith((ref) => Stream.value(<ProductDef>[])),
          ],
          child: const MaterialApp(
            home: ProductTemplatesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppAddFloatingActionButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final appBarIconButtons = find.descendant(of: appBarFinder, matching: find.byType(IconButton));
      expect(appBarIconButtons, findsNothing);

      // Tap FAB to open action sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add product'), findsWidgets);
    });

    testWidgets('KindsPage has Floating Action Button and no plus button in AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kindsListProvider.overrideWith((ref) => Stream.value(<KindDef>[])),
          ],
          child: const MaterialApp(
            home: KindsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppAddFloatingActionButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final appBarIconButtons = find.descendant(of: appBarFinder, matching: find.byType(IconButton));
      expect(appBarIconButtons, findsNothing);

      // Tap FAB to open action sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add kind'), findsWidgets);
    });

    testWidgets('CollectionsPage has Floating Action Button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CollectionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppAddFloatingActionButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Tap FAB to open action sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add collection'), findsWidgets);
    });

    testWidgets('CookingAidPage has Floating Action Button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CookingAidPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppAddFloatingActionButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Tap FAB to open action sheet
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add cooking aid'), findsWidgets);
    });
  });
}
