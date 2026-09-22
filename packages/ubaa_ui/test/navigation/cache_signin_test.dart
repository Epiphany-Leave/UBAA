import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('failed day switch cannot show the previous signing target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: shell(
          tab: 2,
          signinSnapshot: const FeatureSnapshot(
            feature: FeatureId.signin,
            status: FeatureLoadStatus.stale,
            error: UiError(
              code: UbaaErrorCode.networkError,
              title: '读取失败',
              message: '请刷新',
            ),
            details: [
              FeatureDetail(
                title: '旧日期课程',
                actions: [
                  SigninPerformAction(
                    scheduleId: 'old-target',
                    eligibility: ActionEligibility.allowed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('课堂签到'));
    await tester.pumpAndSettle();
    expect(find.text('旧日期课程'), findsNothing);
    expect(find.text('读取失败'), findsOneWidget);
  });
  testWidgets(
    'signin date navigation and explicit refresh preserve selected day',
    (tester) async {
      final queries = <FeatureQuery>[];
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return shell(
                tab: 2,
                onQuery: (_, query) async {
                  queries.add(query);
                  rebuild(() {});
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('课堂签到'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('signin-day-2026-9-23')));
      await tester.pumpAndSettle();
      final tomorrow = DateTime(2026, 9, 23);
      expect(queries.last.date, tomorrow);
      expect(queries.last.refresh, isFalse);
      await tester.tap(find.byTooltip('刷新签到状态'));
      await tester.pumpAndSettle();
      expect(queries.last.date, tomorrow);
      expect(queries.last.refresh, isTrue);
      await tester.tap(find.byTooltip('下一周'));
      await tester.pumpAndSettle();
      expect(queries.last.date, tomorrow.add(const Duration(days: 7)));
      expect(queries.last.refresh, isFalse);
    },
  );
  testWidgets(
    'filter has its own toolbar space and dots have four columns and three rows',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: shell(
            tab: 2,
            signin: SigninDaySummary(
              date: DateTime(2026, 9, 22),
              courses: List.filled(13, SigninDisplayStatus.pending),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('课堂签到'));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('signin-day-2026-9-22'));
      expect(
        tester.getRect(find.byTooltip('筛选')).bottom <= tester.getRect(card).top,
        isTrue,
      );
      final dots = find.descendant(of: card, matching: find.byTooltip('未签到'));
      expect(dots, findsNWidgets(12));
      final rows = <double, int>{};
      for (var i = 0; i < 12; i++) {
        final y = tester.getCenter(dots.at(i)).dy;
        rows[y] = (rows[y] ?? 0) + 1;
      }
      expect(rows.values.toList(), [4, 4, 4]);
      expect(find.text('13门'), findsOneWidget);
      await tester.tap(find.byTooltip('筛选'));
      await tester.pumpAndSettle();
      expect(find.text('全部课程'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'day strip uses local counts and distinguishes queried statuses',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: shell(
            tab: 2,
            onQuery: (_, _) async {},
            signin: SigninDaySummary(
              date: DateTime(2026, 9, 22),
              courses: const [
                SigninDisplayStatus.pending,
                SigninDisplayStatus.signed,
                SigninDisplayStatus.late,
              ],
            ),
            timetable: Timetable(
              terms: const {'20261': '学期'},
              semesters: [
                TimetableSemester(
                  term: '20261',
                  updatedAt: '',
                  weeks: [
                    TimetableWeek(
                      number: 1,
                      name: '周',
                      start: DateTime(2026, 9, 21),
                      end: DateTime(2026, 9, 27),
                      sections: const [],
                      courses: const [
                        TimetableCourse(
                          day: 3,
                          detail: FeatureDetail(title: '课程1'),
                        ),
                        TimetableCourse(
                          day: 3,
                          detail: FeatureDetail(title: '课程2'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('课堂签到'));
      await tester.pumpAndSettle();
      expect(find.text('3门'), findsOneWidget);
      expect(find.text('2门'), findsOneWidget);
      expect(find.byTooltip('未签到'), findsNWidgets(2));
      expect(find.byTooltip('已签到'), findsNWidgets(2));
      expect(find.byTooltip('迟到'), findsNWidgets(2));
      expect(find.byTooltip('待查/未知'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cached page exposes data time and manual refresh', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: shell(
          tab: 1,
          onRetry: (_) async {
            refreshes++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('成绩查询'));
    await tester.pumpAndSettle();
    expect(find.textContaining('数据时间：'), findsOneWidget);
    expect(refreshes, 0);
    await tester.tap(find.byTooltip('刷新本地数据'));
    expect(refreshes, 1);
  });
}

UbaaMainShell shell({
  required int tab,
  Future<void> Function(FeatureId, FeatureQuery)? onQuery,
  Future<void> Function(FeatureId)? onRetry,
  SigninDaySummary? signin,
  Timetable? timetable,
  FeatureSnapshot? signinSnapshot,
}) => UbaaMainShell(
  user: const UserSummary(username: 'fixture'),
  initialTab: tab,
  currentTime: DateTime(2026, 9, 22),
  snapshots: {
    for (final f in FeatureId.values)
      f: f == FeatureId.signin && signinSnapshot != null
          ? signinSnapshot
          : FeatureSnapshot(
              feature: f,
              signinDays: f == FeatureId.signin && signin != null
                  ? [signin]
                  : [],
              timetable: f == FeatureId.schedule ? timetable : null,
              status: FeatureLoadStatus.empty,
              updatedAt: DateTime(2026, 9, 22),
            ),
  },
  routePolicy: RoutePolicy.webvpn,
  telemetryEnabled: false,
  onRefresh: () async {},
  onRetryFeature: onRetry ?? (_) async {},
  onFeatureQuery: onQuery ?? (_, _) async {},
  onLogout: () async {},
  onLogoutAndClearAccount: () async {},
  onRoutePolicyChanged: (_) {},
  onTelemetryChanged: (_) {},
);
