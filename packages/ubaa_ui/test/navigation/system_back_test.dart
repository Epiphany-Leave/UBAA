import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('system back leaves subpage then feature', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: UbaaMainShell(
          user: const UserSummary(username: 'fixture'),
          snapshots: {
            for (final feature in FeatureId.values)
              feature: FeatureSnapshot(
                feature: feature,
                status: FeatureLoadStatus.empty,
              ),
          },
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
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('图书馆座位'));
    await tester.tap(find.text('图书馆座位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的预约'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '我的预约'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '图书馆座位'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '普通功能'), findsOneWidget);
  });
}
