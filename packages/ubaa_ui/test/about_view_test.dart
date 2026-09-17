import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('关于入口显示宿主版本且链接失败可复制', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UbaaMainShell(
          user: const UserSummary(username: 'fixture'),
          snapshots: {
            for (final id in FeatureId.values)
              id: FeatureSnapshot(feature: id, status: FeatureLoadStatus.empty),
          },
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          initialTab: 3,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
          onLoadAppVersion: () async {
            if (attempts++ == 0) throw StateError('unavailable');
            return '1.2.3+16';
          },
          onOpenProject: () async => false,
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('关于 UBAA'), 200);
    await tester.tap(find.text('关于 UBAA'));
    await tester.pumpAndSettle();
    expect(find.text('当前平台暂无法读取版本'), findsOneWidget);
    await tester.tap(find.byTooltip('重试读取版本'));
    await tester.pumpAndSettle();
    expect(find.text('1.2.3+16'), findsOneWidget);
    await tester.tap(find.text('项目主页'));
    await tester.pumpAndSettle();
    expect(find.text('https://github.com/BUAASubnet/UBAA'), findsOneWidget);
    expect(find.text('复制地址'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开源许可'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
