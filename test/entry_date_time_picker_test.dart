import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/ui/widgets/entry_date_time_picker.dart';
import 'package:shiata/ui/widgets/inline_time_picker.dart';

void main() {
  group('EntryDateTimePicker', () {
    testWidgets('time adjustments keep the date and update the time', (
      tester,
    ) async {
      final changes = <DateTime>[];
      var selected = DateTime(2026, 8, 26, 8);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => EntryDateTimePicker(
                  value: selected,
                  onChanged: (value) => setState(() {
                    selected = value;
                    changes.add(value);
                  }),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('When: Aug 26 · 08:00'), findsOneWidget);

      await tester.tap(find.text('+1h'));
      await tester.pumpAndSettle();
      expect(changes.last, DateTime(2026, 8, 26, 9));

      await tester.tap(find.text('+15m'));
      await tester.pumpAndSettle();
      expect(changes.last, DateTime(2026, 8, 26, 9, 15));
    });

    testWidgets('minute wrap keeps the date unchanged', (tester) async {
      DateTime? changed;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EntryDateTimePicker(
                value: DateTime(2026, 8, 26, 23, 45),
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('+15m'));
      await tester.pumpAndSettle();

      expect(changed, DateTime(2026, 8, 26, 23));
    });

    testWidgets('hour wrap keeps the date unchanged', (tester) async {
      DateTime? changed;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EntryDateTimePicker(
                value: DateTime(2026, 8, 26, 23),
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('+1h'));
      await tester.pumpAndSettle();

      expect(changed, DateTime(2026, 8, 26, 0));
    });

    testWidgets('date selection keeps the existing time', (tester) async {
      DateTime? changed;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EntryDateTimePicker(
                value: DateTime(2026, 8, 26, 8, 45),
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('27').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(changed, DateTime(2026, 8, 27, 8, 45));
    });

    testWidgets('can hide the date button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EntryDateTimePicker(
                value: DateTime(2026, 8, 26, 8),
                onChanged: (_) {},
                showDateButton: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today), findsNothing);
      expect(find.byType(InlineTimePicker), findsOneWidget);
    });

    testWidgets('remembers collapsed state across instances', (tester) async {
      var showFirst = true;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    EntryDateTimePicker(
                      key: ValueKey(showFirst),
                      value: DateTime(2026, 8, 26, 8),
                      onChanged: (_) {},
                      title: showFirst ? 'First' : 'Second',
                    ),
                    TextButton(
                      onPressed: () => setState(() => showFirst = !showFirst),
                      child: const Text('Switch instance'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InlineTimePicker), findsOneWidget);
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.byType(InlineTimePicker), findsNothing);

      await tester.tap(find.text('Switch instance'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      expect(find.byType(InlineTimePicker), findsNothing);
    });
  });
}
