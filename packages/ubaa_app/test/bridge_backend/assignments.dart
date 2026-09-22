part of '../bridge_backend_test.dart';

class _FakeSigninClient extends _CompatibleBridgeClient {
  _FakeSigninClient(this.response, {this.future = false});

  final BridgeRoutedSigninClasses response;
  final bool future;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #signinWeek) {
      return Future<BridgeRoutedSigninWeek>.value(
        BridgeRoutedSigninWeek(
          data: [
            BridgeSigninDay(
              date: invocation.namedArguments[#date] as String,
              isFuture: future,
              classes: response.data,
            ),
          ],
          route: response.route,
        ),
      );
    }
    throw UnsupportedError('unexpected bridge call: ${invocation.memberName}');
  }
}

class _FakeSpocClient extends _CompatibleBridgeClient {
  _FakeSpocClient(this.response);

  final BridgeRoutedSpocAssignments response;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #cachedSpocAssignments) {
      return Future<BridgeRoutedSpocAssignments>.value(response);
    }
    throw UnsupportedError('unexpected bridge call: ${invocation.memberName}');
  }
}
