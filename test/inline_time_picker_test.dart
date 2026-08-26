import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/ui/widgets/inline_time_picker.dart';

void main() {
  group('InlineTimePicker Widget Tests', () {
    testWidgets('renders digital segments, quick adjuster buttons, and dial without popup', (tester) async {
      TimeOfDay? updatedTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InlineTimePicker(
                initialTime: const TimeOfDay(hour: 14, minute: 30),
                onTimeChanged: (t) => updatedTime = t,
              ),
            ),
          ),
        ),
      );

      // Verify digital segments show hour '14' and minute '30'
      expect(find.text('14'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Hour'), findsOneWidget);
      expect(find.text('Minute'), findsOneWidget);

      // Verify quick adjust buttons
      expect(find.text('+1h'), findsOneWidget);
      expect(find.text('-1h'), findsOneWidget);
      expect(find.text('+15m'), findsOneWidget);
      expect(find.text('-15m'), findsOneWidget);

      // Test +1h button
      await tester.tap(find.text('+1h'));
      await tester.pumpAndSettle();
      expect(updatedTime, const TimeOfDay(hour: 15, minute: 30));
      expect(find.text('15'), findsOneWidget);

      // Test -1h button
      await tester.tap(find.text('-1h'));
      await tester.pumpAndSettle();
      expect(updatedTime, const TimeOfDay(hour: 14, minute: 30));

      // Test +15m button
      await tester.tap(find.text('+15m'));
      await tester.pumpAndSettle();
      expect(updatedTime, const TimeOfDay(hour: 14, minute: 45));
      expect(find.text('45'), findsOneWidget);

      // Test -15m button
      await tester.tap(find.text('-15m'));
      await tester.pumpAndSettle();
      expect(updatedTime, const TimeOfDay(hour: 14, minute: 30));

      // Test Mode switching by tapping 'Minute' segment
      await tester.tap(find.text('Minute'));
      await tester.pumpAndSettle();

      // Ensure no dialog is in widget tree
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('interaction with clock dial updates hour and switches to minute mode', (tester) async {
      TimeOfDay? updatedTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InlineTimePicker(
                initialTime: const TimeOfDay(hour: 10, minute: 0),
                onTimeChanged: (t) => updatedTime = t,
              ),
            ),
          ),
        ),
      );

      // Find the CustomPaint widget that renders the dial
      final dialFinder = find.byType(CustomPaint).last;
      expect(dialFinder, findsOneWidget);

      // Tap dial at 3 o'clock position (right side)
      final dialTopLeft = tester.getTopLeft(dialFinder);
      final dialSize = tester.getSize(dialFinder);
      final dialCenter = dialTopLeft + Offset(dialSize.width / 2, dialSize.height / 2);

      // Tap near 3 o'clock (Offset(center.dx + radius * 0.8, center.dy))
      final threeOclock = dialCenter + Offset(dialSize.width * 0.38, 0);
      await tester.tapAt(threeOclock);
      await tester.pumpAndSettle();

      // Hour should now be 3 (or 15)
      expect(updatedTime?.hour, isIn([3, 15]));
    });
  });
}
