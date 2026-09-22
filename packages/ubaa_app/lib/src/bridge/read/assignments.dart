part of '../bridge_backend.dart';

Future<FeatureResult> _loadAssignmentFeature(
  BridgeBackend backend,
  FeatureId feature,
  FeatureQuery query,
) async {
  final client = backend.client;
  switch (feature) {
    case FeatureId.spoc:
      switch (query.view) {
        case FeatureQueryView.summary:
          final result = await client.cachedSpocAssignments(
            refresh: query.refresh,
          );
          final details = result.data.assignments
              .map(
                (item) => FeatureDetail(
                  title: item.title,
                  subtitle: item.courseName,
                  fields: _compactFields(<FeatureField?>[
                    _field('课程编号', item.courseId),
                    _field('作业编号', item.assignmentId),
                    _field('教师', item.teacherName),
                    _field('开始', item.startTime),
                    _field('截止', item.dueTime),
                    _field('状态', item.submissionStatusText),
                    _field('得分', item.score),
                  ]),
                ),
              )
              .toList(growable: false);
          return _countResult(
            result.data.assignments.length,
            '项 SPOC 作业',
            details: details,
            resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
            savedAt: result.route.savedAt,
          );
        case FeatureQueryView.spocDetail:
          final assignmentId = _requiredQueryValue(query.assignmentId, '作业编号');
          final result = await client.spocAssignment(
            assignmentId: assignmentId,
          );
          final item = result.data;
          return FeatureResult.success(
            summary: 'SPOC 作业详情',
            details: <FeatureDetail>[
              FeatureDetail(
                title: item.title,
                subtitle: item.courseName,
                fields: _compactFields(<FeatureField?>[
                  _field('作业编号', item.assignmentId),
                  _field('课程编号', item.courseId),
                  _field('教师', item.teacherName),
                  _field('开始', item.startTime),
                  _field('截止', item.dueTime),
                  _field('状态', item.submissionStatusText),
                  _field('得分', item.score),
                  _field('提交时间', item.submittedAt),
                  _field('作业内容', item.contentPlainText),
                ]),
              ),
            ],
            resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
          );
        default:
          throw const BackendException(UbaaErrorCode.invalidInput);
      }
    case FeatureId.judge:
      switch (query.view) {
        case FeatureQueryView.summary:
          final result = await client.cachedJudgeAssignments(
            refresh: query.refresh,
            includeExpired: query.includeExpired,
          );
          final details = result.data
              .map(
                (item) => FeatureDetail(
                  title: item.title,
                  subtitle: item.courseName,
                  fields: _compactFields(<FeatureField?>[
                    _field('课程编号', item.courseId),
                    _field('作业编号', item.assignmentId),
                    _field('开始', item.startTime),
                    _field('截止', item.dueTime),
                    _field('状态', item.submissionStatusText),
                    _field(
                      '进度',
                      '${item.submittedCount}/${item.totalProblems}',
                    ),
                    _field('我的得分', item.myScore),
                  ]),
                ),
              )
              .toList(growable: false);
          return _countResult(
            result.data.length,
            '项希冀作业',
            details: details,
            savedAt: result.route.savedAt,
            resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
          );
        case FeatureQueryView.judgeDetail:
          final courseId = _requiredQueryValue(query.courseId, '课程编号');
          final assignmentId = _requiredQueryValue(query.assignmentId, '作业编号');
          final result = await client.judgeAssignment(
            courseId: courseId,
            assignmentId: assignmentId,
          );
          final item = result.data;
          final problems = item.problems
              .map(
                (problem) => FeatureDetail(
                  title: problem.name,
                  fields: _compactFields(<FeatureField?>[
                    _field('状态', problem.statusText),
                    _field('得分', problem.score),
                    _field('满分', problem.maxScore),
                  ]),
                ),
              )
              .toList(growable: false);
          final details = <FeatureDetail>[
            FeatureDetail(
              title: item.title,
              subtitle: item.courseName,
              fields: _compactFields(<FeatureField?>[
                _field('课程编号', item.courseId),
                _field('作业编号', item.assignmentId),
                _field('开始', item.startTime),
                _field('截止', item.dueTime),
                _field('状态', item.submissionStatusText),
                _field('进度', '${item.submittedCount}/${item.totalProblems}'),
                _field('我的得分', item.myScore),
                _field('作业内容', item.contentPlainText),
              ]),
            ),
            ...problems,
          ];
          return FeatureResult.success(
            summary: '希冀作业详情',
            details: details,
            resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
          );
        case FeatureQueryView.judgeBatchDetails:
          if (query.judgeKeys.isEmpty) {
            throw const BackendException(UbaaErrorCode.invalidInput);
          }
          final result = await client.judgeAssignmentDetails(
            keys: query.judgeKeys
                .map(
                  (key) => BridgeJudgeAssignmentKey(
                    courseId: key.courseId,
                    assignmentId: key.assignmentId,
                  ),
                )
                .toList(growable: false),
          );
          final details = <FeatureDetail>[];
          for (final item in result.data) {
            details.add(
              FeatureDetail(
                title: item.title,
                subtitle: item.courseName,
                fields: _compactFields(<FeatureField?>[
                  _field('课程编号', item.courseId),
                  _field('作业编号', item.assignmentId),
                  _field('开始', item.startTime),
                  _field('截止', item.dueTime),
                  _field('状态', item.submissionStatusText),
                  _field('题目数', '${item.submittedCount}/${item.totalProblems}'),
                  _field('我的得分', item.myScore),
                  _field('作业内容', item.contentPlainText),
                ]),
              ),
            );
            details.addAll(
              item.problems.map(
                (problem) => FeatureDetail(
                  title: problem.name,
                  fields: _compactFields(<FeatureField?>[
                    _field('状态', problem.statusText),
                    _field('得分', problem.score),
                    _field('满分', problem.maxScore),
                  ]),
                ),
              ),
            );
          }
          return FeatureResult.success(
            summary: '${result.data.length}项希冀作业详情',
            details: details,
            resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
          );
        default:
          throw const BackendException(UbaaErrorCode.invalidInput);
      }
    case FeatureId.signin:
      final day =
          query.date ?? DateTime.now().toUtc().add(const Duration(hours: 8));
      final result = await client.signinWeek(
        date: _dateOnly(day),
        refresh: query.refresh,
      );
      final selected = result.data.singleWhere(
        (value) => value.date == _dateOnly(day),
      );
      final overview = result.data
          .map(
            (value) => SigninDaySummary(
              date: DateTime.parse(value.date),
              courses: value.classes
                  .map(
                    (item) => value.isFuture
                        ? SigninDisplayStatus.unknown
                        : switch (item.signStatus) {
                            0 => SigninDisplayStatus.pending,
                            1 => SigninDisplayStatus.signed,
                            _ => SigninDisplayStatus.unknown,
                          },
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false);
      final classes = switch (query.view) {
        FeatureQueryView.summary => selected.classes,
        FeatureQueryView.signinPending =>
          selected.classes
              .where((item) => item.signStatus == 0 && !selected.isFuture)
              .toList(growable: false),
        FeatureQueryView.signinCompleted =>
          selected.classes
              .where((item) => item.signStatus == 1)
              .toList(growable: false),
        _ => throw const BackendException(UbaaErrorCode.invalidInput),
      };
      final details = classes
          .map((item) {
            final eligibility = _toSigninActionEligibility(
              item.signinEligibility,
            );
            final target = item.signinTarget?.trim();
            return FeatureDetail(
              title: item.courseName,
              subtitle: '${item.classBeginTime}–${item.classEndTime}',
              fields: <FeatureField>[
                FeatureField(label: '课程 ID', value: item.courseId),
                FeatureField(
                  label: '签到状态',
                  value: selected.isFuture
                      ? '未到日期'
                      : switch (item.signStatus) {
                          0 => '未签到',
                          1 => '已签到',
                          _ => '状态未知',
                        },
                ),
                if (item.availabilityMessage != null)
                  FeatureField(label: '说明', value: item.availabilityMessage!),
              ],
              actions: target == null || target.isEmpty
                  ? const <FeatureAction>[]
                  : <FeatureAction>[
                      SigninPerformAction(
                        scheduleId: target,
                        eligibility: eligibility,
                      ),
                    ],
            );
          })
          .toList(growable: false);
      if (classes.isEmpty) {
        return FeatureResult.empty(
          signinDays: overview,
          savedAt: DateTime.tryParse(result.route.savedAt ?? ''),
          resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
        );
      }
      final label = switch (query.view) {
        FeatureQueryView.signinPending => '门未签到课程',
        FeatureQueryView.signinCompleted => '门已签到课程',
        _ => '门当日课程',
      };
      return FeatureResult.success(
        summary: '${classes.length}$label',
        signinDays: overview,
        savedAt: DateTime.tryParse(result.route.savedAt ?? ''),
        details: details,
        resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
      );
    default:
      throw StateError('unexpected feature: $feature');
  }
}

ActionEligibility _toSigninActionEligibility(
  BridgeActionEligibility eligibility,
) => switch (eligibility) {
  BridgeActionEligibility.allowed => ActionEligibility.allowed,
  BridgeActionEligibility.denied => ActionEligibility.denied,
  BridgeActionEligibility.unknown => ActionEligibility.unknown,
};
