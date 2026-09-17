import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('图书馆两个入口传递已选楼层并可查看预约', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final queries = <FeatureQuery>[];
    late StateSetter updateSnapshots;
    final snapshots = {
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.empty,
        ),
      FeatureId.libbook: const FeatureSnapshot(
        feature: FeatureId.libbook,
        status: FeatureLoadStatus.success,
        details: [
          FeatureDetail(
            title: '图书馆',
            fields: [
              FeatureField(label: '馆 ID', value: 'library-1'),
              FeatureField(label: '空闲座位', value: '20'),
              FeatureField(label: '总座位', value: '100'),
              FeatureField(label: '楼层 1', value: '二层'),
              FeatureField(label: '楼层 1 ID', value: 'floor-2'),
              FeatureField(label: '楼层 1 空闲', value: '12'),
              FeatureField(label: '楼层 1 总数', value: '40'),
            ],
          ),
        ],
      ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateSnapshots = setState;
            return UbaaMainShell(
              user: const UserSummary(username: 'student'),
              snapshots: snapshots,
              routePolicy: RoutePolicy.auto,
              telemetryEnabled: false,
              initialTab: 1,
              onRefresh: () async {},
              onRetryFeature: (_) async {},
              onFeatureQuery: (_, query) async => queries.add(query),
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
      find.text('图书馆座位'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final libraryCard = find
        .ancestor(of: find.text('图书馆座位'), matching: find.byType(InkWell))
        .first;
    await tester.tapAt(tester.getTopLeft(libraryCard) + const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('预约座位'), findsOneWidget);
    expect(find.text('我的预约'), findsOneWidget);

    await tester.tap(find.text('预约座位'));
    await tester.pumpAndSettle();
    expect(find.text('楼馆'), findsOneWidget);
    expect(find.text('楼层'), findsOneWidget);
    expect(find.text('分区'), findsOneWidget);
    expect(find.text('座位'), findsWidgets);
    expect(find.text('二层 12/40'), findsOneWidget);
    expect(queries.single.view, FeatureQueryView.libbookAreas);
    expect(queries.single.premisesId, 'library-1');
    expect(queries.single.storeyId, 'floor-2');

    updateSnapshots(() {
      snapshots[FeatureId.libbook] = const FeatureSnapshot(
        feature: FeatureId.libbook,
        status: FeatureLoadStatus.success,
        details: [
          FeatureDetail(
            title: '测试分区',
            fields: [FeatureField(label: '分区 ID', value: '6')],
          ),
        ],
      );
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看座位分布'));
    await tester.pumpAndSettle();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final transform = viewer.transformationController!;
    expect(viewer.trackpadScrollCausesScale, isTrue);
    expect(find.textContaining('颜色不代表当前可用状态'), findsOneWidget);
    await tester.tap(find.byTooltip('放大'));
    await tester.pump();
    expect(transform.value.getMaxScaleOnAxis(), 2);
    await tester.tap(find.byTooltip('放大'));
    await tester.tap(find.byTooltip('放大'));
    await tester.pump();
    expect(transform.value.getMaxScaleOnAxis(), 5);
    await tester.tap(find.byTooltip('缩小'));
    await tester.pump();
    expect(transform.value.getMaxScaleOnAxis(), 2.5);
    await tester.tap(find.text('重置'));
    await tester.pump();
    expect(transform.value.getMaxScaleOnAxis(), 1);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byTooltip('返回图书馆座位'), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('图书馆座位'), findsOneWidget);
    await tester.tap(find.text('我的预约'));
    await tester.pumpAndSettle();
    expect(queries.last.view, FeatureQueryView.libbookBookings);
    expect(queries.last.page, 1);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('预约座位'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
