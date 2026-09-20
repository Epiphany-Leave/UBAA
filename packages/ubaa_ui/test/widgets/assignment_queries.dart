part of '../widgets_test.dart';

void _registerAssignmentQueryTests() {
  testWidgets('SPOC 查询控件提交作业详情 typed 参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.spoc
              ? const <FeatureDetail>[
                  FeatureDetail(
                    title: '作业',
                    fields: <FeatureField>[
                      FeatureField(label: '作业编号', value: 'assignment-17'),
                    ],
                  ),
                ]
              : const <FeatureDetail>[],
        ),
    };
    FeatureQuery? received;
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: coordinatedShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (feature, query) async {
            expect(feature, FeatureId.spoc);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('SPOC作业'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('SPOC作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作业列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作业详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('assignment-17').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.spocDetail);
    expect(received?.assignmentId, 'assignment-17');
  });

  testWidgets('希冀查询控件提交作业详情 typed 参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.judge
              ? const <FeatureDetail>[FeatureDetail(title: '作业')]
              : const <FeatureDetail>[],
        ),
    };
    FeatureQuery? received;
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: coordinatedShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (feature, query) async {
            expect(feature, FeatureId.judge);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('希冀作业'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('希冀作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作业列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作业详情'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'course-3');
    await tester.enterText(fields.at(1), 'assignment-17');
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.judgeDetail);
    expect(received?.courseId, 'course-3');
    expect(received?.assignmentId, 'assignment-17');
    expect(received?.includeExpired, isFalse);
  });

  testWidgets('希冀查询控件可包含已过期作业', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.judge
              ? const <FeatureDetail>[FeatureDetail(title: '作业')]
              : const <FeatureDetail>[],
        ),
    };
    FeatureQuery? received;
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: coordinatedShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (feature, query) async {
            expect(feature, FeatureId.judge);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('希冀作业'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('希冀作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('包含已过期作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.includeExpired, isTrue);
  });

  testWidgets('希冀查询控件提交批量作业详情 typed 键', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.judge
              ? const <FeatureDetail>[FeatureDetail(title: '作业')]
              : const <FeatureDetail>[],
        ),
    };
    FeatureQuery? received;
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: coordinatedShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onFeatureQuery: (feature, query) async {
            expect(feature, FeatureId.judge);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('希冀作业'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('希冀作业'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作业列表'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('批量详情'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'course-2/assignment-2\ncourse-1/assignment-1',
    );
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.judgeBatchDetails);
    expect(received?.judgeKeys, const <JudgeAssignmentQueryKey>[
      JudgeAssignmentQueryKey(
        courseId: 'course-2',
        assignmentId: 'assignment-2',
      ),
      JudgeAssignmentQueryKey(
        courseId: 'course-1',
        assignmentId: 'assignment-1',
      ),
    ]);
  });

  testWidgets('首页从离线课表显示今日课程', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          timetable: feature == FeatureId.schedule
              ? Timetable(terms: const {}, semesters: const [])
              : null,
          details: feature == FeatureId.schedule
              ? const <FeatureDetail>[
                  FeatureDetail(title: '离散数学', subtitle: 'MATH101'),
                ]
              : const <FeatureDetail>[],
        ),
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: UbaaTheme.light(),
        home: coordinatedShell(
          user: const UserSummary(username: 'student'),
          snapshots: snapshots,
          routePolicy: RoutePolicy.auto,
          telemetryEnabled: false,
          onRefresh: () async {},
          onRetryFeature: (_) async {},
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('主页').last);
    await tester.pumpAndSettle();
    expect(find.text('今日课程'), findsOneWidget);
    expect(find.text('离散数学'), findsOneWidget);
    expect(find.text('今天没有课程'), findsNothing);
  });
}
