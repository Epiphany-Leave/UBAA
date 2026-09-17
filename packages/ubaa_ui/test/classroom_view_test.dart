import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('空教室按楼栋列表展示并只在校区变化时重新查询', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final queries = <FeatureQuery>[];
    final snapshots = {
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.empty,
        ),
      FeatureId.classroom: const FeatureSnapshot(
        feature: FeatureId.classroom,
        status: FeatureLoadStatus.success,
        details: [
          FeatureDetail(
            title: '主楼 101',
            subtitle: '主楼',
            fields: [FeatureField(label: '可用节次', value: '1,3,14')],
          ),
          FeatureDetail(
            title: '新主楼 B102',
            subtitle: '新主楼',
            fields: [FeatureField(label: '可用节次', value: '2')],
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
          initialTab: 0,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (_, query) async => queries.add(query),
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('空教室查询'));
    await tester.pumpAndSettle();
    expect(find.text('学院路'), findsOneWidget);
    expect(find.text('搜索教室/楼栋'), findsOneWidget);
    expect(find.text('主楼 101'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('主楼'), findsOneWidget);
    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, '主楼')).selected,
      isTrue,
    );
    expect(find.text('新主楼 B102'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, '新主楼'));
    await tester.enterText(find.byType(TextField), '新主楼');
    await tester.pump();
    expect(find.text('主楼 101'), findsNothing);
    expect(find.text('新主楼 B102'), findsOneWidget);
    expect(queries, isEmpty);

    await tester.tap(find.text('沙河'));
    await tester.pump();
    expect(queries.single.campus, 2);
  });
}
