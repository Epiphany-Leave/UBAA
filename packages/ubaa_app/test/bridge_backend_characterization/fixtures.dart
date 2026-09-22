part of '../bridge_backend_characterization_test.dart';

const _readyLoginOutcome = BridgeLoginOutcome(
  readiness: BridgeLoginReadiness.allReady,
  routes: <BridgeRouteLoginResult>[],
);

const _readMembers = <Symbol>{
  #bykcChosenCourses,
  #bykcCourseDetail,
  #bykcCourses,
  #bykcProfile,
  #bykcStatistics,
  #cgyyDayInfo,
  #cgyyLockCode,
  #cgyyOrderDetail,
  #cgyyOrders,
  #cgyyPurposeTypes,
  #cgyySites,
  #classroomSearch,
  #evaluationAll,
  #evaluationAllOnRoute,
  #examArrangement,
  #examTerms,
  #gradeOverview,
  #grades,
  #judgeAssignment,
  #judgeAssignmentDetails,
  #judgeAssignments,
  #libbookAreaDetail,
  #libbookAreas,
  #libbookBookings,
  #libbookLibraries,
  #libbookSeats,
  #scheduleTerms,
  #scheduleToday,
  #scheduleWeek,
  #scheduleWeeks,
  #signinToday,
  #spocAssignment,
  #spocAssignments,
  #ygdkOverview,
  #ygdkOverviewOnRoute,
  #ygdkRecords,
  #ygdkRecordsOnRoute,
};

const _writeMembers = <Symbol, BridgeWriteOperation>{
  #prepareBykcSelectCourse: BridgeWriteOperation.bykcSelectCourse,
  #prepareBykcDeselectCourse: BridgeWriteOperation.bykcDeselectCourse,
  #prepareBykcSignCourse: BridgeWriteOperation.bykcSignCourse,
  #prepareSigninPerform: BridgeWriteOperation.signinPerform,
  #prepareLibbookReserve: BridgeWriteOperation.libbookReserve,
  #prepareLibbookCancelBooking: BridgeWriteOperation.libbookCancelBooking,
  #prepareYgdkSubmit: BridgeWriteOperation.ygdkSubmit,
  #prepareCgyySubmitReservation: BridgeWriteOperation.cgyySubmitReservation,
  #prepareCgyyCancelOrder: BridgeWriteOperation.cgyyCancelOrder,
  #prepareEvaluationSubmitCourses: BridgeWriteOperation.evaluationSubmitCourses,
};

BridgeWriteIntent _bridgeIntent(BridgeWriteOperation operation) =>
    BridgeWriteIntent(
      intentId: 'intent-${operation.name}',
      operation: operation,
      targetSummary: '安全摘要',
      resolvedRoute: BridgeConnectionMode.webVpn,
      warnings: const <String>[],
      expiresAt: 2000000000,
      requestDigest: 'digest-${operation.name}',
    );

BridgeYgdkOverview _ygdkOverviewData(bool emptyReads) => BridgeYgdkOverview(
  summary: const BridgeYgdkTermSummary(termCount: 0),
  classifyId: 31,
  classifyName: '分类',
  defaultItemId: 0,
  defaultItemName: '项目',
  items: emptyReads
      ? const <BridgeYgdkItem>[]
      : const <BridgeYgdkItem>[
          BridgeYgdkItem(
            itemId: 7,
            name: '跑步项目',
            kind: 1,
            submitEligibility: BridgeActionEligibility.allowed,
            submitTarget: BridgeYgdkSubmitTarget(classifyId: 31, itemId: 7),
          ),
        ],
);

BridgeEvaluationCoursesResponse _evaluationCoursesData(bool emptyReads) =>
    BridgeEvaluationCoursesResponse(
      courses: emptyReads
          ? const <BridgeEvaluationCourse>[]
          : const <BridgeEvaluationCourse>[
              BridgeEvaluationCourse(
                id: 'task-read-1_questionnaire-read-1_READ1_teacher-read-1',
                kcmc: '评教课程',
                bpmc: '测试教师',
                isEvaluated: false,
                submitEligibility: BridgeActionEligibility.allowed,
                submitTarget: BridgeEvaluationSubmitTarget(
                  rwid: 'task-read-1',
                  wjid: 'questionnaire-read-1',
                  kcdm: 'READ1',
                  bpdm: 'teacher-read-1',
                ),
              ),
            ],
      progress: BridgeEvaluationProgress(
        totalCourses: emptyReads ? 0 : 1,
        evaluatedCourses: 0,
        pendingCourses: emptyReads ? 0 : 1,
      ),
    );

BridgeYgdkRecordsPage _ygdkRecordsData(
  bool emptyReads, {
  required int page,
  required int size,
}) => BridgeYgdkRecordsPage(
  content: emptyReads
      ? const <BridgeYgdkRecord>[]
      : const <BridgeYgdkRecord>[
          BridgeYgdkRecord(
            recordId: 101,
            itemId: 7,
            itemName: '打卡记录',
            place: '校园',
            imageCount: 2,
            isOpen: false,
          ),
        ],
  total: emptyReads ? 0 : 9,
  page: page,
  size: size,
  hasMore: !emptyReads,
);

BridgeJudgeAssignmentDetail _judgeDetail(
  String courseId,
  String assignmentId, {
  String title = '作业详情',
}) => BridgeJudgeAssignmentDetail(
  courseId: courseId,
  courseName: '课程',
  assignmentId: assignmentId,
  title: title,
  totalProblems: 0,
  submittedCount: 0,
  submissionStatus: BridgeJudgeSubmissionStatus.unsubmitted,
  submissionStatusText: '未提交',
  problems: const <BridgeJudgeProblem>[],
);

String _describeReadCall(Invocation invocation) {
  final named = invocation.namedArguments;
  return switch (invocation.memberName) {
    #bykcCourseDetail => 'bykcCourseDetail:id=${named[#id]}',
    #bykcCourses =>
      'bykcCourses:page=${named[#page]},size=${named[#size]},all=${named[#all]}',
    #cgyyDayInfo => 'cgyyDayInfo:siteId=${named[#siteId]},date=${named[#date]}',
    #cgyyOrderDetail => 'cgyyOrderDetail:id=${named[#id]}',
    #cgyyOrders => 'cgyyOrders:page=${named[#page]},size=${named[#size]}',
    #classroomSearch =>
      'classroomSearch:campus=${named[#campus]},date=${named[#date]}',
    #examArrangement => 'examArrangement:term=${named[#term]}',
    #grades => 'grades:term=${named[#term]}',
    #evaluationAllOnRoute =>
      'evaluationAllOnRoute:route=${(named[#route] as BridgeConnectionMode).name}',
    #judgeAssignment =>
      'judgeAssignment:courseId=${named[#courseId]},assignmentId=${named[#assignmentId]}',
    #judgeAssignmentDetails =>
      'judgeAssignmentDetails:keys=${(named[#keys] as List<BridgeJudgeAssignmentKey>).map((key) => '${key.courseId}/${key.assignmentId}').join(',')}',
    #judgeAssignments =>
      'judgeAssignments:includeExpired=${named[#includeExpired]}',
    #libbookAreaDetail => 'libbookAreaDetail:areaId=${named[#areaId]}',
    #libbookAreas =>
      'libbookAreas:premisesId=${named[#premisesId]},storeyId=${named[#storeyId]},day=${named[#day]}',
    #libbookBookings =>
      'libbookBookings:page=${named[#page]},limit=${named[#limit]}',
    #libbookLibraries => 'libbookLibraries:day=${named[#day]}',
    #libbookSeats =>
      'libbookSeats:areaId=${named[#areaId]},day=${named[#day]},startTime=${named[#startTime]},endTime=${named[#endTime]}',
    #scheduleWeek => 'scheduleWeek:term=${named[#term]},week=${named[#week]}',
    #scheduleWeeks => 'scheduleWeeks:term=${named[#term]}',
    #spocAssignment => 'spocAssignment:assignmentId=${named[#assignmentId]}',
    #ygdkRecords => 'ygdkRecords:page=${named[#page]},size=${named[#size]}',
    #ygdkOverviewOnRoute =>
      'ygdkOverviewOnRoute:route=${(named[#route] as BridgeConnectionMode).name}',
    #ygdkRecordsOnRoute =>
      'ygdkRecordsOnRoute:route=${(named[#route] as BridgeConnectionMode).name},page=${named[#page]},size=${named[#size]}',
    _ => _symbolName(invocation.memberName),
  };
}

String _symbolName(Symbol symbol) =>
    symbol.toString().substring(8, symbol.toString().length - 2);

String _resultText(FeatureResult result) => <String>[
  if (result.summary case final summary?) summary,
  for (final detail in result.details) ...<String>[
    detail.title,
    if (detail.subtitle case final subtitle?) subtitle,
    for (final field in detail.fields) ...<String>[field.label, field.value],
  ],
].join('|');
