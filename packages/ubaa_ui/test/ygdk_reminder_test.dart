import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('提醒开关仅在阳光子页，保存成功后首页显示提醒', (tester) async {
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
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阳光打卡'));
    await tester.pumpAndSettle();
    expect(find.text('阳光打卡首页提醒'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('提醒设置保存失败，请重试'), findsOneWidget);
    expect(saved, isFalse);
    fail = false;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.text('前往阳光打卡'), findsOneWidget);
    await tester.tap(find.text('前往阳光打卡'));
    await tester.pumpAndSettle();
    expect(find.text('阳光打卡'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
}
