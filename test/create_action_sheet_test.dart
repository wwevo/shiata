import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/domain/widgets/create_action.dart';
import 'package:shiata/ui/widgets/create_action_sheet.dart';
import 'package:shiata/ui/widgets/inline_time_picker.dart';

void main() {
  group('CreateActionSheet & showAddActionSheet Tests', () {
    testWidgets('ActiveWeek action sheet content includes InlineTimePicker and passes selected time to action', (tester) async {
      DateTime? executedDateTime;

      final testActions = [
        CreateAction(
          id: 'action_1',
          label: 'Add Oats 50g',
          icon: Icons.rice_bowl,
          color: Colors.green,
          run: (ctx, targetAt) async {
            executedDateTime = targetAt;
          },
        ),
      ];

      final targetDate = DateTime(2026, 8, 26, 8, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: CreateActionSheetContent(
                targetDate: targetDate,
                title: 'Add entry',
                showTimePicker: true,
                actions: testActions,
              ),
            ),
          ),
        ),
      );

      // Verify InlineTimePicker is present on top
      expect(find.byType(InlineTimePicker), findsOneWidget);
      expect(find.text('Add entry'), findsOneWidget);
      expect(find.text('Add Oats 50g'), findsOneWidget);

      // Adjust time with +1h
      await tester.tap(find.text('+1h'));
      await tester.pumpAndSettle();

      // Tap the action chip
      await tester.tap(find.text('Add Oats 50g'));
      await tester.pumpAndSettle();

      expect(executedDateTime, isNotNull);
      expect(executedDateTime!.year, 2026);
      expect(executedDateTime!.month, 8);
      expect(executedDateTime!.day, 26);
      expect(executedDateTime!.hour, 9); // 8 + 1
      expect(executedDateTime!.minute, 0);
    });

    testWidgets('Non-timepicker single action sheet renders prominent action with no timepicker and blank space', (tester) async {
      bool actionRan = false;

      final testActions = [
        CreateAction(
          id: 'add_recipe',
          label: 'Add recipe',
          icon: Icons.restaurant_menu,
          color: Colors.orange,
          run: (ctx, targetAt) async {
            actionRan = true;
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: CreateActionSheetContent(
                targetDate: DateTime.now(),
                title: 'Add recipe',
                showTimePicker: false,
                actions: testActions,
              ),
            ),
          ),
        ),
      );

      // TimePicker must NOT be rendered
      expect(find.byType(InlineTimePicker), findsNothing);
      expect(find.text('Add recipe'), findsNWidgets(2)); // Title and Card label

      await tester.tap(find.text('Add recipe').last);
      await tester.pumpAndSettle();

      expect(actionRan, isTrue);
    });

    testWidgets('showAddActionSheet adapts to Linux (right side sheet) and Android (bottom sheet)', (tester) async {
      // Test Linux side sheet
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.linux),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => showAddActionSheet(
                      context: context,
                      ref: ref,
                      pageId: 'recipes',
                    ),
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify side sheet dialog is displayed aligned to right
      final alignWidgets = tester.widgetList<Align>(find.byType(Align));
      expect(alignWidgets.any((a) => a.alignment == Alignment.centerRight), isTrue);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Test Android bottom sheet
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => showAddActionSheet(
                      context: context,
                      ref: ref,
                      pageId: 'recipes',
                    ),
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify bottom sheet modal is displayed
      expect(find.byType(CreateActionSheetContent), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
