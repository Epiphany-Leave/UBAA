import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('empty timetable imports once and offline entry never imports', (
    tester,
  ) async {
    var calls = 0;
    for (final offline in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: TimetableView(
            key: ValueKey(offline),
            snapshot: const FeatureSnapshot(feature: FeatureId.schedule),
            offline: offline,
            onQuery: (query) async {
              expect(query.view, FeatureQueryView.scheduleWeek);
              calls++;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(calls, offline ? 0 : 1);
    }
  });
  testWidgets('本周跨学期直接定位新 pager', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime.now();
    final data = Timetable(
      terms: const {'old': '旧学期', 'current': '当前学期'},
      semesters: [
        TimetableSemester(
          term: 'old',
          updatedAt: '',
          weeks: [
            TimetableWeek(
              number: 1,
              name: '旧周',
              start: DateTime(2000),
              end: DateTime(2000, 1, 7),
              sections: const [],
              courses: const [],
            ),
          ],
        ),
        TimetableSemester(
          term: 'current',
          updatedAt: '',
          weeks: [
            TimetableWeek(
              number: 2,
              name: '当前周',
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day),
              sections: const [],
              courses: const [],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableView(
            snapshot: FeatureSnapshot(
              feature: FeatureId.schedule,
              timetable: data,
            ),
            onQuery: (_) async {},
          ),
        ),
      ),
    );
    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byTooltip('上一周'), findsNothing);
    await tester.tap(find.byTooltip('课表选项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择学期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旧学期').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('回到本周'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('当前周'), findsWidgets);
  });
  final today = DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  final timetable = Timetable(
    terms: const {'t': '测试学期'},
    semesters: [
      TimetableSemester(
        term: 't',
        updatedAt: '2026-09-10',
        weeks: [
          for (var i = 0; i < 2; i++)
            TimetableWeek(
              number: i + 1,
              name: '第${i + 1}周',
              start: monday.add(Duration(days: i * 7)),
              end: monday.add(Duration(days: i * 7 + 6)),
              sections: [
                for (var s = 1; s <= 13; s++)
                  TimetableSection(s, '08:00', '08:45'),
              ],
              courses: i == 0
                  ? const [
                      TimetableCourse(
                        detail: FeatureDetail(title: '数学'),
                        day: 1,
                        begin: 1,
                        end: 2,
                      ),
                      TimetableCourse(
                        detail: FeatureDetail(title: '英语'),
                        day: 1,
                        begin: 2,
                        end: 3,
                      ),
                      TimetableCourse(
                        detail: FeatureDetail(title: '物理'),
                        day: 1,
                        begin: 3,
                        end: 4,
                      ),
                      TimetableCourse(
                        detail: FeatureDetail(title: '晚课'),
                        day: 1,
                        begin: 6,
                        end: 7,
                      ),
                      TimetableCourse(
                        detail: FeatureDetail(title: '整列对照'),
                        day: 2,
                        begin: 6,
                        end: 7,
                      ),
                      TimetableCourse(
                        detail: FeatureDetail(title: '未知节次'),
                        day: 3,
                      ),
                    ]
                  : const [],
            ),
        ],
      ),
    ],
  );
  testWidgets('课表设置切换周末和时间轴立即生效', (tester) async {
    final settings = AppearanceSettings();
    await tester.pumpWidget(
      AppearanceScope(
        settings: settings,
        child: MaterialApp(
          home: Scaffold(
            body: TimetableView(
              snapshot: FeatureSnapshot(
                feature: FeatureId.schedule,
                timetable: timetable,
              ),
              onQuery: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('周六'), findsOneWidget);
    expect(find.text('1\n08:00\n08:45'), findsOneWidget);
    settings.weekends = false;
    settings.timeline = false;
    await settings.save();
    await tester.pumpAndSettle();
    expect(find.textContaining('周六'), findsNothing);
    expect(find.text('1\n08:00\n08:45'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'weekly pages drag locally, courses open details, update is explicit',
    (tester) async {
      final queries = <FeatureQuery>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimetableView(
              snapshot: FeatureSnapshot(
                feature: FeatureId.schedule,
                status: FeatureLoadStatus.success,
                timetable: timetable,
              ),
              onQuery: (query) async {
                queries.add(query);
              },
            ),
          ),
        ),
      );
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byKey(const ValueKey('week-thumbnail-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('week-thumbnail-2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('week-thumbnail-2')));
      await tester.pumpAndSettle();
      expect(find.text('第2周'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('week-thumbnail-1')));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('数学\n')).right,
        lessThanOrEqualTo(tester.getRect(find.text('英语\n')).left),
      );
      expect(
        tester.getRect(find.text('英语\n')).right,
        lessThanOrEqualTo(tester.getRect(find.text('物理\n')).left),
      );
      expect(
        tester.getRect(find.text('晚课\n')).width,
        closeTo(tester.getRect(find.text('整列对照\n')).width, .01),
      );
      await tester.tap(find.text('数学\n'));
      await tester.pumpAndSettle();
      expect(find.text('数学'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      final pager = find.byType(PageView);
      final viewport = tester.getRect(pager);
      final gesture = await tester.startGesture(viewport.center);
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesture.moveBy(Offset(-viewport.width * .4, 0));
      await tester.pump();
      final pageState = tester.widget<PageView>(pager).controller!;
      expect(pageState.page, greaterThan(0));
      expect(pageState.page, lessThan(1));
      expect(find.textContaining('周日'), findsNWidgets(2));
      await gesture.moveBy(Offset(-viewport.width * .35, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(queries, isEmpty);
      expect(find.text('第2周'), findsWidgets);
      await tester.drag(pager, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('13\n08:00\n08:45').hitTestable(), findsOneWidget);
      expect(find.text('本地化课表'), findsNothing);
      await tester.tap(find.byTooltip('课表选项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('本地化课表'));
      await tester.pumpAndSettle();
      expect(queries.single.updateSchedule, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimetableView(
              snapshot: const FeatureSnapshot(
                feature: FeatureId.schedule,
                status: FeatureLoadStatus.empty,
                timetable: Timetable(terms: {}, semesters: []),
              ),
              onQuery: (query) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('暂无已保存课表，请点击本地化课表'), findsOneWidget);
    },
  );
}
