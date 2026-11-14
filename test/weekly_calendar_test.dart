import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/data/providers.dart';
import 'package:shiata/domain/widgets/registry.dart';
import 'package:shiata/ui/main_screen_providers.dart';
import 'package:shiata/ui/ux_config.dart';
import 'package:shiata/ui/widgets/circle_week_header.dart';
import 'package:shiata/ui/widgets/weekly_calendar.dart';

void main() {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final initialHeaderAnchor = DateTime(2026, 1, 5);
  final pageAnchor = DateTime(2026, 2, 2);

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        headerCalendarAnchorProvider.overrideWith((ref) => initialHeaderAnchor),
        calendarAnchorProvider.overrideWith((ref) => pageAnchor),
        entriesRepositoryProvider.overrideWithValue(null),
        widgetRegistryProvider.overrideWithValue(WidgetRegistry({})),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget calendarApp({
    required double width,
    required double height,
    required ProviderContainer container,
    void Function(DateTime day)? onDayTap,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: WeeklyCalendar(
                grid: const CalendarGridConfig(),
                onDayTap: onDayTap,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('centers weekday cells between week navigation controls', (
    tester,
  ) async {
    final container = createContainer();
    DateTime? tappedDay;

    await tester.pumpWidget(
      calendarApp(
        width: 360,
        height: 80,
        container: container,
        onDayTap: (day) => tappedDay = day,
      ),
    );
    await tester.pumpAndSettle();

    final previous = find.byTooltip('Previous week');
    final next = find.byTooltip('Next week');
    final weekdayCenters = weekdays
        .map((day) => tester.getCenter(find.text(day)).dx)
        .toList();

    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);
    expect(weekdayCenters, orderedEquals([...weekdayCenters]..sort()));
    expect(tester.getCenter(previous).dx, lessThan(weekdayCenters.first));
    expect(tester.getCenter(next).dx, greaterThan(weekdayCenters.last));

    await tester.tap(find.text('Tue'));
    expect(tappedDay, DateTime(2026, 1, 6));

    await tester.tap(previous);
    await tester.pump();
    expect(
      container.read(headerCalendarAnchorProvider),
      DateTime(2025, 12, 29),
    );
    expect(container.read(calendarAnchorProvider), pageAnchor);

    await tester.tap(next);
    await tester.pump();
    expect(container.read(headerCalendarAnchorProvider), initialHeaderAnchor);
    expect(container.read(calendarAnchorProvider), pageAnchor);
  });

  testWidgets('renders without overflow at narrow widths', (tester) async {
    final container = createContainer();

    await tester.pumpWidget(
      calendarApp(width: 240, height: 80, container: container),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Previous week'), findsOneWidget);
    expect(find.byTooltip('Next week'), findsOneWidget);
    for (final weekday in weekdays) {
      expect(find.text(weekday), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final useClassicHeader in [true, false]) {
    final headerName = useClassicHeader ? 'weekly calendar' : 'circle header';
    testWidgets(
      '$headerName week navigation preserves page week and scroll position',
      (tester) async {
        final container = createContainer();
        final pageScrollController = ScrollController();
        addTearDown(pageScrollController.dispose);
        final initialSelectedDay = DateTime(2026, 2, 4);
        container.read(selectedDayProvider.notifier).state = initialSelectedDay;
        container.read(currentSectionIdProvider.notifier).state = 'recipes';

        void handleDayTap(DateTime day) {
          final monday = day.subtract(Duration(days: day.weekday - 1));
          container.read(calendarAnchorProvider.notifier).state = monday;
          container.read(headerCalendarAnchorProvider.notifier).state = monday;
          container.read(selectedDayProvider.notifier).state = day;
          container.read(currentSectionIdProvider.notifier).state =
              'active_week';
        }

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final anchor = ref.watch(headerCalendarAnchorProvider);
                        return SizedBox(
                          height: 80,
                          child: useClassicHeader
                              ? WeeklyCalendar(
                                  grid: const CalendarGridConfig(),
                                  onDayTap: handleDayTap,
                                )
                              : CircleWeekHeader(
                                  monday: anchor,
                                  onDayTap: handleDayTap,
                                ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final pageWeek = ref.watch(calendarAnchorProvider);
                          return Column(
                            children: [
                              Text('Page week: ${pageWeek.toIso8601String()}'),
                              Expanded(
                                child: ListView.builder(
                                  controller: pageScrollController,
                                  itemCount: 40,
                                  itemExtent: 44,
                                  itemBuilder: (context, index) => Text(
                                    'Page entry $index for ${pageWeek.toIso8601String()}',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Scrollable), findsOneWidget);
        pageScrollController.jumpTo(300);
        await tester.pump();
        final pageScrollOffset = pageScrollController.offset;

        await tester.tap(find.byTooltip('Next week'));
        await tester.pumpAndSettle();
        expect(
          container.read(headerCalendarAnchorProvider),
          DateTime(2026, 1, 12),
        );
        expect(container.read(calendarAnchorProvider), pageAnchor);
        expect(container.read(selectedDayProvider), initialSelectedDay);
        expect(container.read(currentSectionIdProvider), 'recipes');
        expect(pageScrollController.offset, pageScrollOffset);

        await tester.tap(find.byTooltip('Previous week'));
        await tester.pumpAndSettle();
        expect(
          container.read(headerCalendarAnchorProvider),
          initialHeaderAnchor,
        );
        expect(container.read(calendarAnchorProvider), pageAnchor);
        expect(container.read(selectedDayProvider), initialSelectedDay);
        expect(container.read(currentSectionIdProvider), 'recipes');
        expect(pageScrollController.offset, pageScrollOffset);

        await tester.tap(find.text('Tue'));
        await tester.pumpAndSettle();
        expect(container.read(calendarAnchorProvider), initialHeaderAnchor);
        expect(
          container.read(headerCalendarAnchorProvider),
          initialHeaderAnchor,
        );
        expect(container.read(selectedDayProvider), DateTime(2026, 1, 6));
        expect(container.read(currentSectionIdProvider), 'active_week');
      },
    );
  }
}
