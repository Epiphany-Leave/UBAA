import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  for (final layout in [
    (size: const Size(390, 844), dark: false, scale: 1.0),
    (size: const Size(390, 844), dark: true, scale: 1.3),
    (size: const Size(1280, 800), dark: false, scale: 1.0),
  ]) {
    testWidgets('首页摘要保留缓存、展示时间地点且不重复功能目录 $layout', (tester) async {
      tester.view
        ..physicalSize = layout.size
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final date = DateTime.now().add(const Duration(days: 2));
      final snapshots = {
        for (final feature in FeatureId.values)
          feature: FeatureSnapshot(
            feature: feature,
            status: FeatureLoadStatus.empty,
          ),
        FeatureId.schedule: const FeatureSnapshot(
          feature: FeatureId.schedule,
          status: FeatureLoadStatus.stale,
          timetable: Timetable(terms: {}, semesters: []),
          details: [
            FeatureDetail(
              title: '离散数学',
              fields: [
                FeatureField(label: '开始时间', value: '08:00'),
                FeatureField(label: '结束时间', value: '09:35'),
                FeatureField(label: '地点', value: '教学楼 A101'),
              ],
            ),
          ],
        ),
        FeatureId.exam: FeatureSnapshot(
          feature: FeatureId.exam,
          status: FeatureLoadStatus.success,
          details: [
            FeatureDetail(
              title: '算法考试',
              fields: [
                FeatureField(
                  label: '考试日期',
                  value: date.toIso8601String().split('T').first,
                ),
                const FeatureField(label: '地点', value: '教学楼 B202'),
              ],
            ),
            const FeatureDetail(
              title: '过往考试',
              fields: [FeatureField(label: '考试日期', value: '2000-01-01')],
            ),
          ],
        ),
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: layout.dark ? UbaaTheme.dark() : UbaaTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(layout.scale)),
            child: child!,
          ),
          home: UbaaMainShell(
            user: const UserSummary(username: 'student'),
            snapshots: snapshots,
            routePolicy: RoutePolicy.auto,
            telemetryEnabled: false,
            onRefresh: () async {},
            onRetryFeature: (_) async {},
            onLogout: () async {},
            onLogoutAndClearAccount: () async {},
            onRoutePolicyChanged: (_) {},
            onTelemetryChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('离散数学'), findsOneWidget);
      expect(find.textContaining('08:00'), findsOneWidget);
      expect(find.textContaining('教学楼 A101'), findsOneWidget);
      expect(find.text('刷新失败，仍显示已保存课表'), findsOneWidget);
      expect(find.text('算法考试'), findsOneWidget);
      expect(find.text('过往考试'), findsNothing);
      expect(find.byType(SliverGrid), findsNothing);
      final all = find.text('全部功能');
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.text('课表查询'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
