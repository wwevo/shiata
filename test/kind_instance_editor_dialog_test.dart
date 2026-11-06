import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/data/providers.dart';
import 'package:shiata/domain/widgets/create_action.dart';
import 'package:shiata/domain/widgets/widget_kind.dart';
import 'package:shiata/ui/editors/kind_instance_editor_dialog.dart';
import 'package:shiata/ui/editors/product_instance_editor_dialog.dart';
import 'package:shiata/ui/widgets/entry_date_time_picker.dart';

class _TestWidgetKind extends WidgetKind {
  const _TestWidgetKind();

  @override
  String get id => 'test';

  @override
  String get displayName => 'Test';

  @override
  IconData get icon => Icons.circle;

  @override
  Color get accentColor => Colors.blue;

  @override
  String get unit => 'g';

  @override
  int get minValue => 0;

  @override
  int get maxValue => 100;

  @override
  bool get defaultShowInCalendar => true;

  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) =>
      const [];
}

void main() {
  testWidgets('renders initial time in EntryDateTimePicker', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: KindInstanceEditorDialog(
            kind: const _TestWidgetKind(),
            initialTargetAt: DateTime(2026, 8, 26, 8, 15),
          ),
        ),
      ),
    );

    expect(find.byType(EntryDateTimePicker), findsOneWidget);
    expect(find.text('When: Aug 26 · 08:15'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  testWidgets('renders EntryDateTimePicker in edit mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entriesRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: ProductEditorDialog(
            entryId: 'existing-entry',
            productId: 'test-product',
            productName: 'Test product',
            initialTargetAt: DateTime(2026, 8, 26, 9, 30),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EntryDateTimePicker), findsOneWidget);
    expect(find.text('When: Aug 26 · 09:30'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsNothing);
  });
}
