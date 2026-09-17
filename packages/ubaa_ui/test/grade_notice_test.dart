import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('首页成绩提示可忽略和进入成绩页', (tester) async {
    var count = 1;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return UbaaMainShell(
              user: const UserSummary(username: 'fixture'),
              snapshots: {
                for (final id in FeatureId.values)
                  id: FeatureSnapshot(
                    feature: id,
                    status: FeatureLoadStatus.empty,
                  ),
              },
              routePolicy: RoutePolicy.auto,
              telemetryEnabled: false,
              gradeChangeCount: count,
              onDismissGradeChanges: () => setState(() => count = 0),
              onRefresh: () async {},
              onRetryFeature: (_) async {},
              onLogout: () async {},
              onLogoutAndClearAccount: () async {},
              onRoutePolicyChanged: (_) {},
              onTelemetryChanged: (_) {},
            );
          },
        ),
      ),
    );
    expect(find.text('最近刷新发现 1 门课程成绩更新'), findsOneWidget);
    await tester.tap(find.text('忽略'));
    await tester.pumpAndSettle();
    expect(find.text('最近刷新发现 1 门课程成绩更新'), findsNothing);
    update(() => count = 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看成绩'));
    await tester.pumpAndSettle();
    expect(find.text('成绩查询'), findsOneWidget);
    expect(count, 0);
  });
}
