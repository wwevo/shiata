import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/ui/widgets/selection_dialog.dart';

void main() {
  group('SelectionDialog', () {
    testWidgets('renders items and selects value', (tester) async {
      String? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await showDialog<String?>(
                    context: context,
                    builder: (ctx) => SelectionDialog<String>(
                      title: 'Pick an option',
                      hint: 'Select option',
                      items: const ['Apple', 'Banana', 'Cherry'],
                      itemLabel: (item) => item,
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.text('Pick an option'), findsOneWidget);
      expect(find.text('Select option'), findsOneWidget);

      // Open the dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Tap on Banana
      await tester.tap(find.text('Banana').last);
      await tester.pumpAndSettle();

      // Tap 'Add' confirm button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(selectedResult, 'Banana');
    });

    testWidgets('cancels without selection', (tester) async {
      String? selectedResult = 'initial';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await showDialog<String?>(
                    context: context,
                    builder: (ctx) => SelectionDialog<String>(
                      title: 'Pick an option',
                      items: const ['Option 1'],
                      itemLabel: (item) => item,
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selectedResult, isNull);
    });
  });
}
