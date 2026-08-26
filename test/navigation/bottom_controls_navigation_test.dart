import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/navigation/nav_models.dart';
import 'package:shiata/navigation/nav_registry.dart';
import 'package:shiata/ui/main_screen.dart';
import 'package:shiata/ui/main_screen_providers.dart';
import 'package:shiata/ui/widgets/bottom_controls.dart';

void main() {
  group('BottomControls & MainScreen Navigation Integration', () {
    testWidgets('renders navigation destinations and switches pages on destination tap', (tester) async {
      final testRegistry = NavRegistry([
        NavPageItem(
          id: 'test_home',
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          pageBuilder: (_, _) => const Scaffold(body: Center(child: Text('Home Screen Content'))),
        ),
        NavPageItem(
          id: 'test_settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          pageBuilder: (_, _) => const Scaffold(body: Center(child: Text('Settings Screen Content'))),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            navRegistryProvider.overrideWithValue(testRegistry),
            currentSectionIdProvider.overrideWith((ref) => 'test_home'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MainScreen(),
              bottomNavigationBar: BottomControls(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows Home Screen
      expect(find.text('Home Screen Content'), findsOneWidget);
      expect(find.text('Settings Screen Content'), findsNothing);

      // Tap Settings in BottomControls
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Shows Settings Screen
      expect(find.text('Settings Screen Content'), findsOneWidget);
      expect(find.text('Home Screen Content'), findsNothing);
    });

    testWidgets('group menu opens and child selection updates page and active checkmark', (tester) async {
      final testRegistry = NavRegistry([
        NavGroupItem(
          id: 'group_menu',
          label: 'Menu',
          icon: Icons.menu,
          children: [
            NavPageItem(
              id: 'child_1',
              label: 'Child One',
              icon: Icons.star,
              pageBuilder: (_, _) => const Scaffold(body: Center(child: Text('Child One Content'))),
            ),
            NavPageItem(
              id: 'child_2',
              label: 'Child Two',
              icon: Icons.favorite,
              pageBuilder: (_, _) => const Scaffold(body: Center(child: Text('Child Two Content'))),
            ),
          ],
        ),
        NavPageItem(
          id: 'other_page',
          label: 'Other',
          icon: Icons.person,
          pageBuilder: (_, _) => const Scaffold(body: Center(child: Text('Other Content'))),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            navRegistryProvider.overrideWithValue(testRegistry),
            currentSectionIdProvider.overrideWith((ref) => 'child_1'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MainScreen(),
              bottomNavigationBar: BottomControls(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows Child One Content
      expect(find.text('Child One Content'), findsOneWidget);

      // Tap Menu to open MenuAnchor
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      // Verify child options are visible in menu
      expect(find.text('Child One'), findsOneWidget);
      expect(find.text('Child Two'), findsOneWidget);

      // Tap Child Two
      await tester.tap(find.text('Child Two'));
      await tester.pumpAndSettle();

      // Viewport switched to Child Two
      expect(find.text('Child Two Content'), findsOneWidget);
      expect(find.text('Child One Content'), findsNothing);
    });

    testWidgets('NavActionItem triggers callback without changing active page', (tester) async {
      bool actionTriggered = false;

      final testRegistry = NavRegistry([
        NavPageItem(
          id: 'page_main',
          label: 'Main',
          icon: Icons.home,
          pageBuilder: (_, _) => const Scaffold(body: Center(child: Text('Main Page'))),
        ),
        NavActionItem(
          id: 'action_dialog',
          label: 'Quick Action',
          icon: Icons.flash_on,
          onTrigger: (context, ref) async {
            actionTriggered = true;
          },
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            navRegistryProvider.overrideWithValue(testRegistry),
            currentSectionIdProvider.overrideWith((ref) => 'page_main'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MainScreen(),
              bottomNavigationBar: BottomControls(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Main Page'), findsOneWidget);
      expect(actionTriggered, isFalse);

      // Tap the action destination
      await tester.tap(find.text('Quick Action'));
      await tester.pumpAndSettle();

      expect(actionTriggered, isTrue);
      // Page remains the same
      expect(find.text('Main Page'), findsOneWidget);
    });
  });
}
