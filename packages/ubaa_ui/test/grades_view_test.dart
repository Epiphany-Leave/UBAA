import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('成绩卡片保留统计和文字成绩，隐藏字段可搜索并打开详情', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UbaaMainShell(
          user: const UserSummary(username: 'fixture'),
          snapshots: {
            for (final id in FeatureId.values)
              id: FeatureSnapshot(feature: id, status: FeatureLoadStatus.empty),
            FeatureId.grades: const FeatureSnapshot(
              feature: FeatureId.grades,
              status: FeatureLoadStatus.success,
              details: [
                FeatureDetail(
                  title: '研究生成绩统计',
                  fields: [
                    FeatureField(label: 'GPA', value: '暂无可计算成绩'),
                    FeatureField(label: 'GPA 计入学分', value: '0'),
                  ],
                ),
                FeatureDetail(
                  title: '测试课程',
                  fields: [
                    FeatureField(label: '成绩', value: '优秀'),
                    FeatureField(label: '学分', value: '2.0'),
                    FeatureField(label: '折算分', value: 'fixture-hidden'),
                  ],
                ),
              ],
            ),
          },
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          initialTab: 1,
          onRefresh: () async {},
          onRetryFeature: (_) async {
            requests++;
          },
          onFeatureQuery: (_, _) async {
            requests++;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('成绩查询'), 200);
    await tester.tap(find.text('成绩查询'));
    await tester.pumpAndSettle();
    expect(find.text('暂无可计算成绩'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('优秀'), findsOneWidget);
    expect(find.text('fixture-hidden'), findsNothing);
    final beforeSearch = requests;
    await tester.tap(find.byTooltip('搜索当前结果'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'fixture-hidden');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('测试课程'), findsOneWidget);
    expect(requests, beforeSearch);
    await tester.tap(find.text('测试课程'));
    await tester.pumpAndSettle();
    expect(find.text('成绩详情'), findsOneWidget);
    expect(find.text('fixture-hidden'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
