import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets(
    'only confirmed enrollment success opens chosen courses for calendar export',
    (tester) async {
      for (final flags in [(true, false), (false, false), (true, true)]) {
        await tester.pumpWidget(const SizedBox());
        final queries = <FeatureQuery>[];
        final result = WriteCommitResult(
          operation: WriteOperation.bykcSelectCourse,
          success: flags.$1,
          outcomeUnknown: flags.$2,
          message: '提交结果',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: UbaaMainShell(
              user: null,
              snapshots: {
                for (final id in FeatureId.values)
                  id: FeatureSnapshot(
                    feature: id,
                    status: FeatureLoadStatus.empty,
                  ),
              },
              routePolicy: RoutePolicy.direct,
              telemetryEnabled: false,
              onRefresh: () async {},
              onRetryFeature: (_) async {},
              onLogout: () async {},
              onLogoutAndClearAccount: () async {},
              onRoutePolicyChanged: (_) {},
              onTelemetryChanged: (_) {},
              writeState: WriteState(
                phase: WritePhase.ready,
                intent: WriteIntent(
                  intentId: 'calendar-test',
                  operation: WriteOperation.bykcSelectCourse,
                  targetSummary: '测试课程',
                  resolvedRoute: ConnectionMode.direct,
                  warnings: const [],
                  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
                  requestDigest: 'test',
                ),
              ),
              onConfirmWrite: () async => WriteOutcome(
                operation: result.operation,
                result: result,
                message: result.message,
              ),
              onFeatureQuery: (_, query) async => queries.add(query),
            ),
          ),
        );
        await tester.tap(find.text('确认提交'));
        await tester.pumpAndSettle();
        expect(
          queries.map((q) => q.view).toList(),
          flags.$1 && !flags.$2
              ? [FeatureQueryView.bykcChosenCourses]
              : isEmpty,
        );
      }
    },
  );
  const course = FeatureDetail(title: '测试课程');
  const draft = CalendarDraft(
    title: '测试课程',
    location: '',
    description: '',
    startMs: 100,
    endMs: 200,
  );
  BoyaCalendarActions actions({
    bool available = true,
    bool valid = true,
    Future<List<CalendarEvent>> Function(CalendarDraft)? read,
  }) => BoyaCalendarActions(
    available: () async => available,
    draft: (_, _) => valid ? draft : null,
    conflicts: read ?? (_) async => [],
    edit: (_) async => '已取消添加日程。',
  );
  Future<void> mount(
    WidgetTester tester,
    BoyaCalendarActions callbacks, {
    bool selected = false,
    bool preview = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BoyaCalendarCard(
              course: course,
              actions: callbacks,
              selected: selected,
              preview: preview,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'preview can check and create reminder, unselected cannot add course',
    (tester) async {
      await mount(tester, actions());
      expect(find.text('添加选课提醒'), findsOneWidget);
      expect(find.text('添加课程日程'), findsNothing);
      await tester.tap(find.text('检测日程冲突'));
      await tester.pumpAndSettle();
      expect(find.textContaining('未发现重叠'), findsOneWidget);
      await tester.tap(find.text('添加选课提醒'));
      await tester.pumpAndSettle();
      expect(find.text('已取消添加日程。'), findsOneWidget);
    },
  );
  testWidgets(
    'selected course offers export and unavailable platform hides controls',
    (tester) async {
      await mount(tester, actions(), selected: true);
      expect(find.text('添加课程日程'), findsOneWidget);
      expect(find.text('添加选课提醒'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, actions(available: false));
      expect(find.text('手机日历'), findsNothing);
    },
  );
  testWidgets('permission failure and invalid dates never say no conflict', (
    tester,
  ) async {
    for (final callbacks in [
      actions(valid: false),
      actions(
        read: (_) async {
          throw const CalendarFailure('权限拒绝，未完成检测');
        },
      ),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, callbacks);
      await tester.tap(find.text('检测日程冲突'));
      await tester.pumpAndSettle();
      expect(find.textContaining('未发现重叠'), findsNothing);
      expect(find.textContaining(RegExp('缺少有效时间|未完成检测')), findsOneWidget);
    }
  });
  testWidgets(
    'conflict details clear on background and late responses after leaving are ignored',
    (tester) async {
      const event = CalendarEvent(
        title: '私人安排',
        location: '测试地点',
        calendar: '个人',
        startMs: 50,
        endMs: 250,
        allDay: true,
        free: true,
      );
      await mount(tester, actions(read: (_) async => [event]));
      await tester.tap(find.text('检测日程冲突'));
      await tester.pumpAndSettle();
      expect(find.textContaining('私人安排'), findsOneWidget);
      expect(find.textContaining('个人 · 测试地点'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('私人安排'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final pending = Completer<List<CalendarEvent>>();
      await mount(tester, actions(read: (_) => pending.future));
      await tester.tap(find.text('检测日程冲突'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete([event]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
