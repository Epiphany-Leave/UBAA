part of '../widgets_test.dart';

void _registerQueryTests() {
  final now = DateTime.now();
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  testWidgets('课堂签到控件提交未签到本地派生视图', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.signin
              ? const <FeatureDetail>[FeatureDetail(title: '签到课程')]
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
            expect(feature, FeatureId.signin);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课堂签到'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<FeatureQueryView>, '未签到'),
    );
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.signinPending);
  });

  testWidgets('课堂签到已完成时禁用重复签到入口', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.signin
              ? const <FeatureDetail>[
                  FeatureDetail(
                    title: '已完成签到课程',
                    fields: <FeatureField>[
                      FeatureField(label: '课程 ID', value: '误导目标'),
                      FeatureField(label: '签到状态', value: '未签到'),
                    ],
                    actions: <FeatureAction>[
                      SigninPerformAction(
                        scheduleId: 'schedule-done',
                        eligibility: ActionEligibility.denied,
                      ),
                    ],
                  ),
                ]
              : const <FeatureDetail>[],
        ),
    };
    var prepareCalls = 0;
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
          onPrepareSigninWrite: (_) async {
            prepareCalls++;
            throw StateError('should not be called');
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课堂签到'));
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '准备签到'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('该课程已签到，不能重复提交。'), findsOneWidget);
    expect(prepareCalls, 0);
  });

  testWidgets('课堂签到 action 缺失或 unknown 时默认拒绝', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.signin
              ? const <FeatureDetail>[
                  FeatureDetail(
                    title: '缺失 action',
                    fields: <FeatureField>[
                      FeatureField(label: '课程 ID', value: 'legacy-target'),
                      FeatureField(label: '签到状态', value: '未签到'),
                    ],
                  ),
                  FeatureDetail(
                    title: '未知资格',
                    actions: <FeatureAction>[
                      SigninPerformAction(
                        scheduleId: 'unknown-target',
                        eligibility: ActionEligibility.unknown,
                      ),
                    ],
                  ),
                ]
              : const <FeatureDetail>[],
        ),
    };
    var prepareCalls = 0;
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
          onPrepareSigninWrite: (_) async {
            prepareCalls++;
            throw StateError('unknown action must not be called');
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课堂签到'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '准备签到'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '准备签到'),
    );
    expect(button.onPressed, isNull);
    expect(prepareCalls, 0);
  });

  testWidgets('考试查询控件提交已安排本地派生视图', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.exam
              ? const <FeatureDetail>[FeatureDetail(title: '考试')]
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
            expect(feature, FeatureId.exam);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('考试查询'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部考试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已安排'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.examArranged);
  });

  testWidgets('成绩查询控件提交已出成绩本地派生视图', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.grades
              ? const <FeatureDetail>[FeatureDetail(title: '成绩')]
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
            expect(feature, FeatureId.grades);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('成绩查询'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部成绩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已出成绩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.gradesScored);
  });

  testWidgets('研究生考试按日期分组且成绩展示统计', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: switch (feature) {
            FeatureId.exam => const <FeatureDetail>[
              FeatureDetail(
                title: '数值分析',
                fields: <FeatureField>[
                  FeatureField(label: '考试日期', value: '2026-09-20'),
                  FeatureField(label: '地点', value: '主楼 A201'),
                  FeatureField(label: '安排状态', value: '已安排'),
                ],
              ),
              FeatureDetail(
                title: '学术英语',
                fields: <FeatureField>[
                  FeatureField(label: '安排状态', value: '未安排'),
                ],
              ),
            ],
            FeatureId.grades => const <FeatureDetail>[
              FeatureDetail(
                title: '研究生成绩统计',
                fields: <FeatureField>[
                  FeatureField(label: 'GPA', value: '3.750'),
                  FeatureField(label: '加权均分', value: '88.50'),
                ],
              ),
              FeatureDetail(
                title: '数值分析',
                fields: <FeatureField>[
                  FeatureField(label: '成绩', value: '90'),
                  FeatureField(label: '成绩制', value: '百分制'),
                ],
              ),
            ],
            _ => const <FeatureDetail>[],
          },
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

    await tester.tap(find.text('考试查询'));
    await tester.pumpAndSettle();
    expect(find.text('已安排考试'), findsOneWidget);
    expect(find.text('2026-09-20'), findsOneWidget);
    expect(find.text('未安排考试'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('成绩查询'));
    await tester.pumpAndSettle();
    expect(find.text('成绩统计'), findsOneWidget);
    expect(find.text('课程成绩'), findsOneWidget);
    expect(find.text('3.750'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
  });

  testWidgets('博雅查询控件提交课程详情 typed 参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.bykc
              ? const <FeatureDetail>[
                  FeatureDetail(
                    title: '课程',
                    fields: [FeatureField(label: '课程 ID', value: '12345')],
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
            expect(feature, FeatureId.bykc);
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
      find.text('博雅课程'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('博雅课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.bykcDetail);
    expect(received?.courseId, '12345');
  });

  testWidgets('博雅查询控件提交修读统计视图', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.bykc
              ? const <FeatureDetail>[FeatureDetail(title: '课程')]
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
            expect(feature, FeatureId.bykc);
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
      find.text('博雅课程'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('博雅课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程统计'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.bykcStatistics);
  });

  testWidgets('课表查询控件提交学期和周次 typed 参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          timetable: feature == FeatureId.schedule
              ? Timetable(
                  terms: const {'2026-2027-1': '2026 Fall'},
                  semesters: [
                    TimetableSemester(
                      term: '2026-2027-1',
                      updatedAt: '2026-09-10',
                      weeks: [
                        for (var i = 0; i < 2; i++)
                          TimetableWeek(
                            number: i + 2,
                            name: 'Week ${i + 2}',
                            start: monday.add(Duration(days: i * 7)),
                            end: monday.add(Duration(days: i * 7 + 6)),
                            sections: const [],
                            courses: const [],
                          ),
                      ],
                    ),
                  ],
                )
              : null,
          details: feature == FeatureId.schedule
              ? const <FeatureDetail>[FeatureDetail(title: '高等数学')]
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
            expect(feature, FeatureId.schedule);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('课表查询'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '学期编码（可选）'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(received, isNull);
    expect(find.text('Week 3'), findsWidgets);
  });

  testWidgets('课表查询控件回到本周无需输入参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          timetable: feature == FeatureId.schedule
              ? Timetable(
                  terms: const {'2026-2027-1': '2026 Fall'},
                  semesters: [
                    TimetableSemester(
                      term: '2026-2027-1',
                      updatedAt: '2026-09-10',
                      weeks: [
                        for (var i = 0; i < 2; i++)
                          TimetableWeek(
                            number: i + 2,
                            name: 'Week ${i + 2}',
                            start: monday.add(Duration(days: i * 7)),
                            end: monday.add(Duration(days: i * 7 + 6)),
                            sections: const [],
                            courses: const [],
                          ),
                      ],
                    ),
                  ],
                )
              : null,
          details: feature == FeatureId.schedule
              ? const <FeatureDetail>[FeatureDetail(title: '课表')]
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
            expect(feature, FeatureId.schedule);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('课表查询'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('回到本周'));
    await tester.pumpAndSettle();
    expect(received, isNull);
  });

  testWidgets('博雅查询控件提交 1-based 分页参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          pagination: feature == FeatureId.bykc
              ? const FeaturePagination(
                  page: 1,
                  size: 20,
                  total: 41,
                  totalPages: 3,
                  hasMore: true,
                )
              : null,
          details: feature == FeatureId.bykc
              ? const <FeatureDetail>[FeatureDetail(title: '课程')]
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
            expect(feature, FeatureId.bykc);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('博雅课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择课程'));
    await tester.pumpAndSettle();
    expect(received?.page, 1);
    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();
    expect(received?.page, 2);
    expect(received?.view, FeatureQueryView.summary);
  });

  testWidgets('阳光打卡查询控件提交记录分页 typed 参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.ygdk
              ? const <FeatureDetail>[FeatureDetail(title: '打卡概览')]
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
            expect(feature, FeatureId.ygdk);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阳光打卡'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('概览'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录列表'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '3');
    await tester.enterText(fields.at(1), '15');
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.ygdkRecords);
    expect(received?.page, 3);
    expect(received?.size, 15);
  });

  testWidgets('场馆查询控件提交日期空间 typed 参数', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.cgyy
              ? const <FeatureDetail>[
                  FeatureDetail(
                    title: '测试楼层',
                    fields: [FeatureField(label: '站点 ID', value: '17')],
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
            expect(feature, FeatureId.cgyy);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('研讨室预约'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('研讨室预约'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('预约研讨室'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('测试楼层'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.cgyyDayInfo);
    expect(received?.siteId, 17);
    expect(received?.date, DateUtils.dateOnly(DateTime.now()));
  });

  testWidgets('评教查询控件提交待评本地派生视图', (tester) async {
    final snapshots = <FeatureId, FeatureSnapshot>{
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.success,
          summary: '已加载',
          details: feature == FeatureId.evaluation
              ? const <FeatureDetail>[FeatureDetail(title: '评教')]
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
            expect(feature, FeatureId.evaluation);
            received = query;
          },
          onLogout: () async {},
          onLogoutAndClearAccount: () async {},
          onRoutePolicyChanged: (_) {},
          onTelemetryChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('教学评教'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('教学评教'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('待评课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pumpAndSettle();
    expect(received?.view, FeatureQueryView.evaluationPending);
  });
}
