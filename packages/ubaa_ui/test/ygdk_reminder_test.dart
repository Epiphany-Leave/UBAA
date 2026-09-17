import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('首页提醒保存失败不生效，重新进入保留开关并可前往打卡', (tester) async {
    var saved = false, fail = true;
    Widget app() => MaterialApp(
      home: UbaaMainShell(
        user: const UserSummary(username: 'fixture'),
        snapshots: {
          for (final id in FeatureId.values)
            id: FeatureSnapshot(feature: id, status: FeatureLoadStatus.empty),
        },
        routePolicy: RoutePolicy.auto,
        telemetryEnabled: false,
        onLoadYgdkReminder: () async => saved,
        onSaveYgdkReminder: (value) async {
          if (fail) throw StateError('unavailable');
          saved = value;
        },
        onRefresh: () async {},
        onRetryFeature: (_) async {},
        onLogout: () async {},
        onLogoutAndClearAccount: () async {},
        onRoutePolicyChanged: (_) {},
        onTelemetryChanged: (_) {},
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('前往阳光打卡'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('提醒设置保存失败，请重试'), findsOneWidget);
    expect(saved, isFalse);
    fail = false;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('前往阳光打卡'), findsOneWidget);
    await tester.tap(find.text('前往阳光打卡'));
    await tester.pumpAndSettle();
    expect(find.text('阳光打卡'), findsOneWidget);
  });
}
