import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('阳光概览切换历史卡片且详情字段仍可搜索', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final queries = <FeatureQuery>[];
    FeatureQuery? query;
    var snapshot = const FeatureSnapshot(
      feature: FeatureId.ygdk,
      status: FeatureLoadStatus.success,
      summary: '本学期认定次数 3 / 10\n本周打卡 1 / 3',
      details: [FeatureDetail(title: '跑步')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return UbaaMainShell(
              user: const UserSummary(username: 'fixture'),
              snapshots: {
                for (final feature in FeatureId.values)
                  feature: FeatureSnapshot(
                    feature: feature,
                    status: FeatureLoadStatus.empty,
                  ),
                FeatureId.ygdk: snapshot,
              },
              routePolicy: RoutePolicy.auto,
              telemetryEnabled: false,
              initialTab: 2,
              onRefresh: () async {},
              onRetryFeature: (_) async {},
              onFeatureQuery: (_, next) async {
                queries.add(next);
                query = next;
                setState(() {
                  snapshot = const FeatureSnapshot(
                    feature: FeatureId.ygdk,
                    status: FeatureLoadStatus.success,
                    summary: '1 条打卡记录',
                    details: [
                      FeatureDetail(
                        title: '晨跑',
                        subtitle: '2026-09-16 09:00',
                        fields: [
                          FeatureField(label: '记录编号', value: 'record-test'),
                          FeatureField(
                            label: '开始时间',
                            value: '2026-09-16 08:00',
                          ),
                          FeatureField(
                            label: '结束时间',
                            value: '2026-09-16 08:30',
                          ),
                          FeatureField(label: '地点', value: '测试操场'),
                          FeatureField(label: '图片数量', value: '1'),
                          FeatureField(label: '公开状态', value: '不公开'),
                        ],
                      ),
                    ],
                  );
                });
              },
              onLogout: () async {},
              onLogoutAndClearAccount: () async {},
              onRoutePolicyChanged: (_) {},
              onTelemetryChanged: (_) {},
            );
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('阳光打卡'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('阳光打卡'));
    await tester.pumpAndSettle();
    expect(find.textContaining('本学期认定次数'), findsOneWidget);
    await tester.tap(find.text('历史记录'));
    await tester.pumpAndSettle();
    expect(query?.view, FeatureQueryView.ygdkRecords);
    expect(query?.page, 1);
    expect(find.text('record-test'), findsNothing);
    await tester.tap(find.text('晨跑'));
    await tester.pumpAndSettle();
    expect(find.text('记录详情'), findsOneWidget);
    expect(find.text('record-test'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索当前结果'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'record-test');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('晨跑'), findsOneWidget);
    expect(queries.length, 1);
    expect(tester.takeException(), isNull);
  });
}
