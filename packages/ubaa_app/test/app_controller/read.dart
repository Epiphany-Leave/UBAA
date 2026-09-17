part of '../app_controller_test.dart';

void _registerReadTests() {
  test('成绩变化仅比较同学期课程，失败不覆盖基线，注销清理提示', () async {
    String? score;
    var term = '20261';
    var fail = false;
    final controller = AppController(
      backend: _GradeNoticeBackend(
        load: (_) async {
          if (fail) throw const BackendException(UbaaErrorCode.networkError);
          return FeatureResult.success(
            resolvedRoute: ConnectionMode.direct,
            details: [
              FeatureDetail(
                title: '测试课程',
                subtitle: 'course-1',
                fields: [
                  FeatureField(label: '学期', value: term),
                  if (score != null) FeatureField(label: '成绩', value: score),
                ],
              ),
            ],
          );
        },
      ),
    );
    addTearDown(controller.dispose);
    Future<void> refresh() => controller.refreshHome(only: [FeatureId.grades]);
    await refresh();
    expect(controller.gradeChangeCount, 0);
    score = '优秀';
    await refresh();
    expect(controller.gradeChangeCount, 1);
    controller.dismissGradeChanges();
    await refresh();
    expect(controller.gradeChangeCount, 0);
    score = null;
    await refresh();
    score = '优秀';
    await refresh();
    expect(controller.gradeChangeCount, 0);
    score = '良好';
    await controller.refreshFeatureQuery(
      FeatureId.grades,
      const FeatureQuery(view: FeatureQueryView.gradesScored),
    );
    expect(controller.gradeChangeCount, 0);
    fail = true;
    score = '良好';
    await refresh();
    expect(controller.gradeChangeCount, 0);
    fail = false;
    await refresh();
    expect(controller.gradeChangeCount, 1);
    controller.dismissGradeChanges();
    term = '20262';
    await refresh();
    expect(controller.gradeChangeCount, 0);
    score = '合格';
    await refresh();
    expect(controller.gradeChangeCount, 1);
    await controller.logout();
    expect(controller.gradeChangeCount, 0);
    await refresh();
    expect(controller.gradeChangeCount, 0);
  });

  test('刷新失败时保留上次数据并标记 stale', () async {
    var loads = 0;
    final backend = _FlakyBackend(
      load: (_) async {
        loads++;
        if (loads > 1) {
          throw const BackendException(UbaaErrorCode.networkError);
        }
        return const FeatureResult.success(
          summary: '上次成功数据',
          details: <FeatureDetail>[
            FeatureDetail(title: '课程', subtitle: '保留内容'),
          ],
        );
      },
    );
    final controller = AppController(backend: backend);
    await controller.refreshHome(only: const <FeatureId>[FeatureId.schedule]);
    expect(
      controller.snapshots[FeatureId.schedule]!.status,
      FeatureLoadStatus.success,
    );
    await controller.refreshHome(only: const <FeatureId>[FeatureId.schedule]);
    final snapshot = controller.snapshots[FeatureId.schedule]!;
    expect(snapshot.status, FeatureLoadStatus.stale);
    expect(snapshot.details.single.title, '课程');
    expect(snapshot.error?.code, UbaaErrorCode.networkError);
    controller.dispose();
  });

  test('Core 明确返回空结果时清除上次成功摘要和详情', () async {
    var loads = 0;
    final backend = _FlakyBackend(
      load: (_) async {
        loads++;
        return loads == 1
            ? const FeatureResult.success(
                summary: '上次成功数据',
                details: <FeatureDetail>[FeatureDetail(title: '课程')],
              )
            : const FeatureResult.empty();
      },
    );
    final controller = AppController(backend: backend);
    await controller.refreshHome(only: const <FeatureId>[FeatureId.schedule]);
    await controller.refreshHome(only: const <FeatureId>[FeatureId.schedule]);
    final snapshot = controller.snapshots[FeatureId.schedule]!;
    expect(snapshot.status, FeatureLoadStatus.empty);
    expect(snapshot.summary, isNull);
    expect(snapshot.details, isEmpty);
    controller.dispose();
  });

  test('明确空结果后刷新失败不伪造成 stale 旧数据', () async {
    var loads = 0;
    final backend = _FlakyBackend(
      load: (_) async {
        loads++;
        if (loads == 1) return const FeatureResult.empty();
        throw const BackendException(UbaaErrorCode.networkError);
      },
    );
    final controller = AppController(backend: backend);
    await controller.refreshHome(only: const <FeatureId>[FeatureId.schedule]);
    await controller.refreshHome(only: const <FeatureId>[FeatureId.schedule]);
    final snapshot = controller.snapshots[FeatureId.schedule]!;
    expect(snapshot.status, FeatureLoadStatus.failure);
    expect(snapshot.summary, isNull);
    expect(snapshot.details, isEmpty);
    expect(snapshot.error?.code, UbaaErrorCode.networkError);
    controller.dispose();
  });

  test('读取结果保留 Core 实际解析路线而不使用配置策略替代', () async {
    final backend = _FlakyBackend(
      load: (_) async => const FeatureResult.success(
        summary: 'WebVPN 数据',
        details: <FeatureDetail>[FeatureDetail(title: '课程')],
        resolvedRoute: ConnectionMode.webvpn,
      ),
    );
    final controller = AppController(backend: backend);
    await controller.refreshHome(only: const <FeatureId>[FeatureId.schedule]);
    expect(
      controller.snapshots[FeatureId.schedule]!.resolvedRoute,
      ConnectionMode.webvpn,
    );
    controller.dispose();
  });

  test('切换到未认证固定路线时清除用户状态并回到登录页', () async {
    final backend = _RouteStateBackend(
      activeRoutes: const <ConnectionMode>[ConnectionMode.webvpn],
    );
    final controller = AppController(backend: backend);
    await controller.initialize();
    expect(controller.phase, AppPhase.home);
    expect(controller.loginForm.routePolicy, RoutePolicy.auto);

    await controller.setRoutePolicy(RoutePolicy.direct);

    expect(controller.phase, AppPhase.login);
    expect(controller.user, isNull);
    expect(controller.loginForm.routePolicy, RoutePolicy.direct);
    expect(
      controller.snapshots.values.every(
        (snapshot) => snapshot.status == FeatureLoadStatus.idle,
      ),
      isTrue,
    );
    controller.dispose();
  });

  test('领域查询参数通过 FeatureQueryBackend typed 传递', () async {
    FeatureQuery? received;
    final backend = _QueryBackend(
      onQuery: (_, query) {
        received = query;
        return const FeatureResult.success(
          summary: '指定查询',
          details: <FeatureDetail>[FeatureDetail(title: '查询结果')],
        );
      },
    );
    final controller = AppController(backend: backend);
    await controller.refreshFeatureQuery(
      FeatureId.classroom,
      FeatureQuery(
        date: DateTime(2026, 9, 2),
        campus: 2,
        week: 3,
        page: 1,
        size: 10,
      ),
    );
    expect(received?.campus, 2);
    expect(received?.week, 3);
    expect(received?.page, 1);
    expect(controller.snapshots[FeatureId.classroom]!.summary, '指定查询');
    controller.dispose();
  });
}
