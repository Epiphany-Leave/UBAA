import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('研讨室三入口使用共用返回并从站点自动查询时段', (tester) async {
    final queries = <FeatureQuery>[];
    final snapshots = {
      for (final id in FeatureId.values)
        id: FeatureSnapshot(feature: id, status: FeatureLoadStatus.empty),
    };
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return UbaaMainShell(
              user: const UserSummary(username: 'test'),
              snapshots: snapshots,
              routePolicy: RoutePolicy.auto,
              telemetryEnabled: false,
              initialTab: 2,
              onRefresh: () async {},
              onRetryFeature: (_) async {},
              onFeatureQuery: (id, query) async {
                queries.add(query);
                final details = switch (query.view) {
                  FeatureQueryView.summary => const [
                    FeatureDetail(
                      title: '二层',
                      subtitle: '主楼',
                      fields: [
                        FeatureField(label: '站点 ID', value: '4'),
                        FeatureField(label: '校区', value: '学院路'),
                      ],
                    ),
                  ],
                  FeatureQueryView.cgyyPurposeTypes => const [
                    FeatureDetail(
                      title: '学习研讨',
                      fields: [FeatureField(label: '用途编号', value: '1')],
                    ),
                  ],
                  FeatureQueryView.cgyyDayInfo => const [
                    FeatureDetail(
                      title: '201 10:00-11:00',
                      fields: [
                        FeatureField(label: '研讨室', value: '201'),
                        FeatureField(label: '时段', value: '10:00-11:00'),
                      ],
                    ),
                  ],
                  _ => const <FeatureDetail>[],
                };
                update(
                  () => snapshots[id] = FeatureSnapshot(
                    feature: id,
                    status: FeatureLoadStatus.success,
                    details: details,
                  ),
                );
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
    await tester.tap(find.text('研讨室预约'));
    await tester.pumpAndSettle();
    expect(find.text('预约研讨室'), findsOneWidget);
    expect(find.text('我的预约'), findsOneWidget);
    expect(find.text('查看密码'), findsOneWidget);
    await tester.tap(find.text('预约研讨室'));
    await tester.pumpAndSettle();
    expect(
      queries.map((q) => q.view),
      containsAllInOrder([
        FeatureQueryView.summary,
        FeatureQueryView.cgyyPurposeTypes,
        FeatureQueryView.cgyyDayInfo,
      ]),
    );
    expect(queries.last.siteId, 4);
    expect(find.text('主楼 二层'), findsOneWidget);
    expect(find.text('站点 ID'), findsNothing);
    expect(find.text('10:00-11:00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看密码'));
    await tester.pumpAndSettle();
    expect(queries.last.view, FeatureQueryView.cgyyLockCode);
  });
}
