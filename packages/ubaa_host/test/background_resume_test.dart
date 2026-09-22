import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_app/ubaa_app.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_host/ubaa_host.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('background preserves session and loaded data', (tester) async {
    final backends = <_Backend>[];
    await tester.pumpWidget(
      UbaaAppHost(
        backendFactory: () {
          final backend = _Backend();
          backends.add(backend);
          return backend;
        },
      ),
    );
    await tester.pumpAndSettle();
    final reads = backends.single.reads;
    expect(find.byType(UbaaMainShell), findsOneWidget);
    for (var cycle = 0; cycle < 3; cycle++) {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pumpAndSettle();
      }
    }
    expect(backends, hasLength(1));
    expect(backends.single.disposals, 0);
    expect(backends.single.reads, reads);
    expect(find.byType(UbaaMainShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(backends.single.disposals, 1);
  });
}

class _Backend implements UbaaBackend, BackendLifecycle {
  int disposals = 0;
  int reads = 0;
  @override
  Future<AuthStatus> authStatus() async => AuthStatus.signedIn;
  @override
  Future<UserSummary?> userInfo() async =>
      const UserSummary(username: 'fixture');
  @override
  Future<void> prepareLogin(RoutePolicy policy) async {}
  @override
  Future<void> login(LoginInput input) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<FeatureResult> loadFeature(FeatureId feature) async {
    reads++;
    return const FeatureResult.empty();
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}
