import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

import 'support/write_harness.dart';

void main() {
  testWidgets('博雅首页通过三个入口查询并使用统一返回键', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final queries = <FeatureQuery>[];
    var snapshots = {
      for (final feature in FeatureId.values)
        feature: FeatureSnapshot(
          feature: feature,
          status: FeatureLoadStatus.empty,
        ),
      FeatureId.bykc: FeatureSnapshot(
        feature: FeatureId.bykc,
        status: FeatureLoadStatus.success,
        details: List.generate(
          20,
          (index) => FeatureDetail(
            title: '测试博雅课程 ${index + 1}',
            subtitle: '测试教师',
            fields: const [FeatureField(label: '状态', value: 'available')],
            actions: const [
              BykcSelectAction(
                courseId: 42,
                eligibility: ActionEligibility.allowed,
              ),
            ],
          ),
        ),
      ),
    };
    late StateSetter updateHost;
    WriteOperation? preparedOperation;
    int? preparedCourseId;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return coordinatedShell(
              user: const UserSummary(username: 'student'),
              snapshots: snapshots,
              routePolicy: RoutePolicy.auto,
              telemetryEnabled: false,
              initialTab: 1,
              onRefresh: () async {},
              onRetryFeature: (_) async {},
              onFeatureQuery: (_, query) async {
                queries.add(query);
                if (query.view == FeatureQueryView.bykcDetail) {
                  updateHost(() {
                    snapshots = {
                      ...snapshots,
                      FeatureId.bykc: const FeatureSnapshot(
                        feature: FeatureId.bykc,
                        status: FeatureLoadStatus.success,
                        details: [
                          FeatureDetail(
                            title: '测试博雅课程',
                            subtitle: '测试教师',
                            fields: [
                              FeatureField(label: '课程 ID', value: '42'),
                              FeatureField(label: '地点', value: '学院路主楼'),
                              FeatureField(label: '开课单位', value: '人文学院'),
                              FeatureField(label: '课程分类', value: '博雅课程 / 美育'),
                              FeatureField(label: '适用人群', value: '研究生'),
                              FeatureField(label: '课程简介', value: '课程简介正文'),
                              FeatureField(label: '状态', value: 'available'),
                              FeatureField(label: '选课开始', value: '2026-09-01'),
                              FeatureField(label: '选课截止', value: '2026-09-30'),
                            ],
                            actions: [
                              BykcSelectAction(
                                courseId: 42,
                                eligibility: ActionEligibility.unknown,
                              ),
                            ],
                          ),
                        ],
                      ),
                    };
                  });
                } else if (query.view == FeatureQueryView.bykcStatistics) {
                  updateHost(() {
                    snapshots = {
                      ...snapshots,
                      FeatureId.bykc: const FeatureSnapshot(
                        feature: FeatureId.bykc,
                        status: FeatureLoadStatus.success,
                        summary: '有效课程 3',
                        details: [
                          FeatureDetail(
                            title: '博雅课程',
                            subtitle: '德育',
                            fields: [
                              FeatureField(label: '要求数量', value: '2'),
                              FeatureField(label: '通过数量', value: '2'),
                              FeatureField(label: '达标', value: '是'),
                            ],
                          ),
                          FeatureDetail(
                            title: '博雅课程',
                            subtitle: '美育',
                            fields: [
                              FeatureField(label: '要求数量', value: '2'),
                              FeatureField(label: '通过数量', value: '1'),
                              FeatureField(label: '达标', value: '否'),
                            ],
                          ),
                        ],
                      ),
                    };
                  });
                }
              },
              onPrepareBykcWrite: (operation, courseId) async {
                preparedOperation = operation;
                preparedCourseId = courseId;
                return WriteIntent(
                  intentId: 'bykc-intent',
                  operation: operation,
                  targetSummary: '测试博雅课程',
                  resolvedRoute: ConnectionMode.direct,
                  warnings: const [],
                  expiresAt: DateTime.now().add(const Duration(minutes: 1)),
                  requestDigest: 'digest',
                );
              },
              onDiscardWriteIntent: (_) async {},
              onLogout: () async {},
              onLogoutAndClearAccount: () async {},
              onRoutePolicyChanged: (_) {},
              onTelemetryChanged: (_) {},
            );
          },
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
    expect(find.text('选择课程'), findsOneWidget);
    expect(find.text('我的课程'), findsOneWidget);
    expect(find.text('课程统计'), findsOneWidget);

    await tester.tap(find.text('选择课程'));
    await tester.pumpAndSettle();
    expect(queries.last.view, FeatureQueryView.summary);
    expect(find.text('测试博雅课程 1'), findsOneWidget);
    await tester.tap(find.text('测试博雅课程 1'));
    await tester.pumpAndSettle();
    expect(queries.last.view, FeatureQueryView.bykcDetail);
    expect(queries.last.courseId, '42');
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('学院路主楼'), findsOneWidget);
    expect(find.text('人文学院'), findsOneWidget);
    expect(find.text('适用范围'), findsOneWidget);
    expect(find.text('研究生'), findsOneWidget);
    expect(find.text('课程简介正文'), findsOneWidget);
    await tester.ensureVisible(find.text('准备选课'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('准备选课'));
    await tester.pumpAndSettle();
    expect(preparedOperation, WriteOperation.bykcSelectCourse);
    expect(preparedCourseId, 42);
    expect(find.text('确认博雅选课'), findsWidgets);
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('全部课程'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的课程'));
    await tester.pumpAndSettle();
    expect(queries.last.view, FeatureQueryView.bykcChosenCourses);
    expect(find.byTooltip('返回'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('选择课程'), findsOneWidget);

    await tester.tap(find.text('课程统计'));
    await tester.pumpAndSettle();
    expect(queries.last.view, FeatureQueryView.bykcStatistics);
    expect(find.text('总体净有效次数'), findsOneWidget);
    expect(find.text('德育'), findsOneWidget);
    expect(find.text('美育'), findsOneWidget);
    expect(find.text('达标'), findsWidgets);
    expect(find.text('未达标'), findsOneWidget);
    final firstCard = find
        .ancestor(of: find.text('德育'), matching: find.byType(Card))
        .first;
    final nextCard = find
        .ancestor(of: find.text('美育'), matching: find.byType(Card))
        .first;
    expect(
      tester.getTopLeft(nextCard).dy - tester.getBottomLeft(firstCard).dy,
      greaterThanOrEqualTo(8),
    );
    expect(tester.takeException(), isNull);
  });
}
