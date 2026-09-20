part of '../widgets_test.dart';

void _registerLibbookQueryTests() {
  testWidgets('图书馆查询控件提交分区和时段 typed 参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.libbook
              ? const <FeatureDetail>[
                  FeatureDetail(
                    title: '图书馆',
                    fields: [
                      FeatureField(label: '馆 ID', value: 'main-library'),
                      FeatureField(label: '楼层 1', value: '一层'),
                      FeatureField(label: '楼层 1 ID', value: 'floor-1'),
                    ],
                  ),
                ]
              : const <FeatureDetail>[],
        ),
    };
    FeatureQuery? received;
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: coordinatedShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (feature, query) async {
            expect(feature, FeatureId.libbook);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('图书馆座位'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('图书馆座位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预约座位'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.libbookAreas);
    expect(received?.premisesId, 'main-library');
    expect(received?.storeyId, 'floor-1');
  });

  testWidgets('图书馆座位查询在时段编号为空时不提交', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.libbook
              ? const <FeatureDetail>[FeatureDetail(title: '图书馆')]
              : const <FeatureDetail>[],
        ),
    };
    var queryCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: coordinatedShell(
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

    await tester.scrollUntilVisible(
      find.text('图书馆座位'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('图书馆座位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预约座位'));
    await tester.pumpAndSettle();

    expect(queryCalls, 0);
    expect(find.text('座位'), findsWidgets);
    expect(
      find
          .byType(FilledButton)
          .evaluate()
          .every(
            (element) => (element.widget as FilledButton).onPressed == null,
          ),
      isTrue,
    );
  });
}
