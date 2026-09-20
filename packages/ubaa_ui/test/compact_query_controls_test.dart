import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('功能详情使用顶部筛选菜单执行查询且不显示实际路线', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    FeatureQuery? received;
    final snapshots = {
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.empty,
        ),
      FeatureId.exam: const FeatureSnapshot(
        feature: FeatureId.exam,
        status: FeatureLoadStatus.success,
        resolvedRoute: ConnectionMode.direct,
        details: [
          FeatureDetail(
            title: '测试考试',
            fields: [
              FeatureField(label: '考试日期', value: '2026-09-20'),
              FeatureField(label: '时间', value: '09:00–11:00'),
              FeatureField(label: '地点', value: '测试教室'),
              FeatureField(label: '座位', value: '12'),
              FeatureField(label: '类型', value: '闭卷'),
              FeatureField(label: '安排状态', value: '已安排'),
            ],
          ),
        ],
      ),
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: UbaaMainShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          initialTab: 1,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (feature, query) async => received = query,
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('考试查询'));
    await tester.pumpAndSettle();
    expect(find.text('实际路线：直连'), findsNothing);
    expect(find.byTooltip('筛选'), findsOneWidget);
    expect(find.byTooltip('搜索当前结果'), findsOneWidget);
    expect(find.byTooltip('查询'), findsNothing);
    expect(find.text('全部考试'), findsNothing);
    expect(find.text('闭卷'), findsNothing);
    expect(find.text('座位 12'), findsOneWidget);
    await tester.tap(find.text('测试考试'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('闭卷'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索当前结果'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '闭卷');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('测试考试'), findsOneWidget);
    expect(received, isNull);

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部考试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已安排'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.examArranged);
    expect(tester.takeException(), isNull);
  });

  testWidgets('四个查询页在空数据时也固定显示搜索', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final snapshots = {
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.empty,
        ),
    };

    for (final title in const ['SPOC作业', '希冀作业', '成绩查询', '考试查询']) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(title),
          home: UbaaMainShell(
            user: const UserSummary(username: 'student'),
            snapshots: snapshots,
            routePolicy: RoutePolicy.auto,
            telemetryEnabled: false,
            initialTab: 1,
            onRefresh: () async {},
            onRetryFeature: (_) async {},
            onFeatureQuery: (_, _) async {},
            onLogout: () async {},
            onLogoutAndClearAccount: () async {},
            onRoutePolicyChanged: (_) {},
            onTelemetryChanged: (_) {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text(title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final card = find
          .ancestor(of: find.text(title), matching: find.byType(InkWell))
          .first;
      await tester.tapAt(tester.getTopLeft(card) + const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byTooltip('搜索当前结果'), findsOneWidget, reason: title);
    }
  });

  testWidgets('详情搜索只过滤当前结果且不重新请求', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var queryCalls = 0;
    final snapshots = {
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.empty,
        ),
      FeatureId.spoc: const FeatureSnapshot(
        feature: FeatureId.spoc,
        status: FeatureLoadStatus.success,
        details: [FeatureDetail(title: '编程课程')],
      ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: UbaaMainShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (_, _) async => queryCalls++,
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.apps_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('SPOC作业'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('SPOC作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索当前结果'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pump();
    expect(queryCalls, 0);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('编程课程'), findsNothing);
  });
}
