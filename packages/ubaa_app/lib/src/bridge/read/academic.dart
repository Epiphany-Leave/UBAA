part of '../bridge_backend.dart';

Future<FeatureResult> _loadSavedSchedule(
  BridgeBackend backend,
  FeatureQuery query,
) async {
  if (!const {
    FeatureQueryView.summary,
    FeatureQueryView.scheduleToday,
    FeatureQueryView.scheduleTerms,
    FeatureQueryView.scheduleWeeks,
    FeatureQueryView.scheduleWeek,
  }.contains(query.view)) {
    throw const BackendException(UbaaErrorCode.invalidInput);
  }
  var saved = query.updateSchedule
      ? await backend.client.updateSavedSchedule(term: query.term)
      : await backend.client.savedSchedule();
  if (!query.updateSchedule &&
      query.view == FeatureQueryView.scheduleWeek &&
      saved.semesters.isEmpty) {
    saved = await backend.client.updateSavedSchedule(term: query.term);
  }
  final timetable = Timetable(
    terms: {for (final term in saved.terms) term.itemCode: term.itemName},
    semesters: [
      for (final semester in saved.semesters)
        TimetableSemester(
          term: semester.term,
          updatedAt: semester.updatedAt,
          weeks: [
            for (var i = 0; i < semester.weeks.length; i++)
              TimetableWeek(
                number: semester.weeks[i].serialNumber,
                name: semester.weeks[i].name,
                start: DateTime.tryParse(semester.weeks[i].startDate),
                end: DateTime.tryParse(semester.weeks[i].endDate),
                sections: i >= semester.schedules.length
                    ? []
                    : [
                        for (final section
                            in semester.schedules[i].sectionTimes)
                          TimetableSection(
                            section.section,
                            section.startTime,
                            section.endTime,
                          ),
                      ],
                courses: i >= semester.schedules.length
                    ? []
                    : [
                        for (final course in semester.schedules[i].arrangedList)
                          TimetableCourse(
                            day: course.dayOfWeek,
                            begin: course.beginSection,
                            end: course.endSection,
                            place: course.placeName,
                            color: course.color,
                            detail: FeatureDetail(
                              title: course.courseName,
                              subtitle: course.courseCode,
                              fields: _compactFields([
                                _field('课程序号', course.courseSerialNo),
                                _field('学分', course.credit),
                                _field('开始时间', course.beginTime),
                                _field('结束时间', course.endTime),
                                _field(
                                  '节次',
                                  course.beginSection == null
                                      ? '未提供'
                                      : '${course.beginSection}–${course.endSection ?? course.beginSection}',
                                ),
                                _field('地点', course.placeName),
                                _field('周次与教师', course.weeksAndTeachers),
                                _field('教学对象', course.teachingTarget),
                              ]),
                            ),
                          ),
                      ],
              ),
          ],
        ),
    ],
  );
  if (saved.semesters.isEmpty) return FeatureResult.empty(timetable: timetable);
  final now = query.date ?? DateTime.now();
  final current = timetable.semesters
      .expand((semester) => semester.weeks)
      .where((week) => week.contains(now))
      .firstOrNull;
  final details =
      current?.courses
          .where((course) => course.day == now.weekday)
          .map((course) => course.detail)
          .toList() ??
      <FeatureDetail>[];
  return FeatureResult.success(
    summary: '今日 ${details.length} 门课程',
    details: details,
    timetable: timetable,
  );
}

Future<FeatureResult> _loadAcademicFeature(
  BridgeBackend backend,
  FeatureId feature,
  FeatureQuery query,
  String today,
) async {
  final client = backend.client;
  switch (feature) {
    case FeatureId.schedule:
      return _loadSavedSchedule(backend, query);
    case FeatureId.exam:
      switch (query.view) {
        case FeatureQueryView.summary:
        case FeatureQueryView.examArranged:
        case FeatureQueryView.examNotArranged:
          final term = query.term ?? await _selectedExamTerm(backend);
          if (term == null) return const FeatureResult.empty();
          final result = await client.examArrangement(term: term);
          final exams = switch (query.view) {
            FeatureQueryView.examArranged => [
              for (final item in result.data.arranged)
                (item: item, arranged: true),
            ],
            FeatureQueryView.examNotArranged => [
              for (final item in result.data.notArranged)
                (item: item, arranged: false),
            ],
            _ => [
              for (final item in result.data.arranged)
                (item: item, arranged: true),
              for (final item in result.data.notArranged)
                (item: item, arranged: false),
            ],
          };
          final details = exams
              .map(
                (exam) => FeatureDetail(
                  title: exam.item.courseName,
                  subtitle: exam.item.examTimeDescription ?? exam.item.examDate,
                  fields: _compactFields(<FeatureField?>[
                    _field('考试日期', exam.item.examDate),
                    _field(
                      '时间',
                      exam.item.startTime == null || exam.item.endTime == null
                          ? null
                          : '${exam.item.startTime}–${exam.item.endTime}',
                    ),
                    _field('地点', exam.item.examPlace),
                    _field('座位', exam.item.examSeatNo),
                    _field('类型', exam.item.examType),
                    FeatureField(
                      label: '安排状态',
                      value: exam.arranged ? '已安排' : '未安排',
                    ),
                  ]),
                ),
              )
              .toList(growable: false);
          final label = switch (query.view) {
            FeatureQueryView.examArranged => '已安排考试',
            FeatureQueryView.examNotArranged => '未安排考试',
            _ => '考试安排',
          };
          return _countResult(
            exams.length,
            label,
            details: details,
            resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
          );
        default:
          throw const BackendException(UbaaErrorCode.invalidInput);
      }
    case FeatureId.grades:
      switch (query.view) {
        case FeatureQueryView.summary:
        case FeatureQueryView.gradesScored:
        case FeatureQueryView.gradesMissing:
          final overview = query.term == null
              ? await client.gradeOverview()
              : null;
          late final List<BridgeGrade> allGrades;
          late final BridgeRouteDecision route;
          if (overview?.data.graduate ?? false) {
            allGrades = overview!.data.grades;
            route = overview.route;
          } else {
            final term = query.term ?? await _selectedTerm(backend);
            if (term == null) return const FeatureResult.empty();
            final result = await client.grades(term: term);
            allGrades = result.data.grades;
            route = result.route;
          }
          final grades = switch (query.view) {
            FeatureQueryView.gradesScored =>
              allGrades
                  .where((item) => item.score?.trim().isNotEmpty ?? false)
                  .toList(growable: false),
            FeatureQueryView.gradesMissing =>
              allGrades
                  .where((item) => !(item.score?.trim().isNotEmpty ?? false))
                  .toList(growable: false),
            _ => allGrades,
          };
          final details = grades
              .map(
                (item) => FeatureDetail(
                  title: item.courseName ?? item.courseCode ?? '课程',
                  subtitle: item.courseCode,
                  fields: _compactFields(<FeatureField?>[
                    _field('成绩', item.score),
                    _field('绩点', item.gradePoint),
                    item.credit == null ? null : _field('学分', '${item.credit}'),
                    item.averageScore == null
                        ? null
                        : _field('折算分', item.averageScore!.toStringAsFixed(2)),
                    _field('成绩制', item.scoreType),
                    _field('课程类型', item.courseType),
                    _field('学期', item.termName ?? item.termCode),
                  ]),
                ),
              )
              .toList();
          if (overview?.data.graduate == true &&
              query.view == FeatureQueryView.summary) {
            final statistics = overview!.data.statistics;
            if (statistics != null) {
              details.insert(0, _gradeStatisticsDetail('研究生成绩统计', statistics));
            }
            details.addAll(
              overview.data.terms.map(
                (term) =>
                    _gradeStatisticsDetail(term.termName, term.statistics),
              ),
            );
          }
          final label = switch (query.view) {
            FeatureQueryView.gradesScored => '门已出成绩课程',
            FeatureQueryView.gradesMissing => '门待出成绩课程',
            _ => '门课程成绩',
          };
          if (overview?.data.graduate == true &&
              query.view == FeatureQueryView.summary) {
            return FeatureResult.success(
              summary: grades.isEmpty
                  ? '暂无成绩，统计将在成绩公布后更新'
                  : '${grades.length}$label',
              details: details,
              resolvedRoute: _toConnectionMode(route.resolvedRoute),
            );
          }
          return _countResult(
            grades.length,
            label,
            details: details,
            resolvedRoute: _toConnectionMode(route.resolvedRoute),
          );
        default:
          throw const BackendException(UbaaErrorCode.invalidInput);
      }
    case FeatureId.classroom:
      final result = await client.classroomSearch(
        campus: query.campus ?? 1,
        date: today,
      );
      final floorFilter = query.floorId?.trim();
      final sectionFilter = query.section?.trim();
      final details = <FeatureDetail>[
        for (final floor in result.data.floors)
          for (final room in floor.rooms)
            if (_matchesClassroomFloor(room, floor.name, floorFilter) &&
                _matchesClassroomSection(room.availableSections, sectionFilter))
              FeatureDetail(
                title: room.name,
                subtitle: floor.name,
                fields: _compactFields(<FeatureField?>[
                  _field('可用节次', room.availableSections),
                ]),
              ),
      ];
      return _countResult(
        details.length,
        '间可用教室',
        details: details,
        resolvedRoute: _toConnectionMode(result.route.resolvedRoute),
      );
    default:
      throw StateError('unexpected feature: $feature');
  }
}

Future<String?> _selectedTerm(BridgeBackend backend) async {
  final result = await backend.client.scheduleTerms();
  for (final term in result.data) {
    if (term.selected && term.itemCode.trim().isNotEmpty) return term.itemCode;
  }
  for (final term in result.data) {
    if (term.itemCode.trim().isNotEmpty) return term.itemCode;
  }
  return null;
}

Future<String?> _selectedExamTerm(BridgeBackend backend) async {
  final result = await backend.client.examTerms();
  for (final term in result.data) {
    if (term.selected && term.itemCode.trim().isNotEmpty) return term.itemCode;
  }
  for (final term in result.data) {
    if (term.itemCode.trim().isNotEmpty) return term.itemCode;
  }
  return null;
}

FeatureDetail _gradeStatisticsDetail(
  String title,
  BridgeGradeStatistics statistics,
) => FeatureDetail(
  title: title,
  fields: <FeatureField>[
    FeatureField(
      label: 'GPA',
      value: statistics.gpa?.toStringAsFixed(3) ?? '暂无可计算成绩',
    ),
    FeatureField(
      label: '加权均分',
      value: statistics.averageScore?.toStringAsFixed(2) ?? '暂无可计算成绩',
    ),
    FeatureField(label: 'GPA 计入学分', value: '${statistics.gpaCredits}'),
    FeatureField(label: '均分计入学分', value: '${statistics.averageCredits}'),
  ],
);

bool _matchesClassroomFloor(
  BridgeClassroomInfo room,
  String floorName,
  String? filter,
) {
  if (filter == null || filter.isEmpty) return true;
  final normalized = filter.toLowerCase();
  return room.floorId.trim().toLowerCase() == normalized ||
      floorName.trim().toLowerCase() == normalized;
}

/// 冻结 `kxsds`/`availableSections` 是逗号分隔的节次序号；只匹配完整令牌，
/// 避免把第 3 节误命中为第 13 节。
bool _matchesClassroomSection(String available, String? filter) {
  if (filter == null || filter.isEmpty) return true;
  return available
      .split(',')
      .map((item) => item.trim())
      .any((item) => item == filter);
}
