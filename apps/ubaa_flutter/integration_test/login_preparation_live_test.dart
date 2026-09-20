import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ubaa_bindings/ubaa_bindings.dart';
import 'package:ubaa_platform/ubaa_platform.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android login preparation without credentials',
    (tester) async {
      await RustLib.init();
      final client = BridgeClient.open(
        configDir: '${defaultConfigDirectory()}-login-probe',
      );
      var stage = 'save route policy';
      try {
        await client.setDefaultRoutePolicy(policy: BridgeRoutePolicy.auto);
        stage = 'prepare login pages';
        final result = await client.prepareLogin();
        for (final route in result.routes) {
          expect(
            route.state,
            BridgeRouteLoginState.ready,
            reason:
                '${route.route}: ${route.error?.code} ${route.error?.message}',
          );
        }
      } on BridgeError catch (error) {
        fail('$stage: ${error.code} ${error.message}');
      } finally {
        await client.dispose();
      }
    },
    skip: !const bool.fromEnvironment('UBAA_LIVE_LOGIN_PROBE'),
  );
}
