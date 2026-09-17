import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_app/ubaa_app.dart';
import 'package:ubaa_bindings/ubaa_bindings.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

class SavedClient implements BridgeClient {
  int updates = 0;
  bool failUpdate = false;
  BridgeSavedSchedule saved = const BridgeSavedSchedule(
    terms: [],
    semesters: [],
  );
  @override
  int contractVersion() => 12;
  @override
  Future<BridgeSavedSchedule> savedSchedule() async => saved;
  @override
  Future<BridgeSavedSchedule> updateSavedSchedule({String? term}) async {
    updates++;
    if (failUpdate) throw StateError('offline');
    return savedSchedule();
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected network call: ${invocation.memberName}');
}

void main() {
  test(
    'home stays offline and first weekly visit imports missing data',
    () async {
      final client = SavedClient();
      final backend = BridgeBackend(client);
      final result = await backend.loadFeature(FeatureId.schedule);
      expect(result.isEmpty, isTrue);
      await backend.loadFeatureQuery(
        FeatureId.schedule,
        const FeatureQuery(view: FeatureQueryView.scheduleWeek),
      );
      expect(client.updates, 1);
      await backend.loadFeatureQuery(
        FeatureId.schedule,
        const FeatureQuery(updateSchedule: true),
      );
      expect(client.updates, 2);
    },
  );
  test('today is derived from dates rather than saved curWeek', () async {
    final client = SavedClient()
      ..saved = const BridgeSavedSchedule(
        terms: [],
        semesters: [
          BridgeSavedSemester(
            term: 'term',
            updatedAt: '2026-09-10',
            weeks: [
              BridgeWeek(
                startDate: '2026-09-07',
                endDate: '2026-09-13',
                term: 'term',
                curWeek: false,
                serialNumber: 1,
                name: '第1周',
              ),
            ],
            schedules: [
              BridgeWeeklySchedule(
                code: '1',
                name: '第1周',
                sectionTimes: [
                  BridgeSectionTime(
                    section: 1,
                    startTime: '08:00',
                    endTime: '08:45',
                  ),
                ],
                arrangedList: [
                  BridgeCourseClass(
                    courseCode: 'math',
                    courseName: '高等数学',
                    dayOfWeek: 4,
                    beginSection: 1,
                    endSection: 1,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    final backend = BridgeBackend(client);
    final result = await backend.loadFeatureQuery(
      FeatureId.schedule,
      FeatureQuery(date: DateTime(2026, 9, 10)),
    );
    expect(result.details.single.title, '高等数学');
    expect(
      result.timetable!.semesters.single.weeks.single.sections.single.start,
      '08:00',
    );
    final other = await backend.loadFeatureQuery(
      FeatureId.schedule,
      FeatureQuery(date: DateTime(2026, 9, 11)),
    );
    expect(other.details, isEmpty);
    expect(client.updates, 0);
    final controller = AppController(backend: backend);
    addTearDown(controller.dispose);
    await controller.refreshFeatureQuery(
      FeatureId.schedule,
      const FeatureQuery(),
    );
    final cached = controller.snapshots[FeatureId.schedule]!.timetable;
    client.failUpdate = true;
    await controller.refreshFeatureQuery(
      FeatureId.schedule,
      const FeatureQuery(updateSchedule: true),
    );
    expect(
      controller.snapshots[FeatureId.schedule]!.status,
      FeatureLoadStatus.stale,
    );
    expect(controller.snapshots[FeatureId.schedule]!.timetable, same(cached));
    client.saved = const BridgeSavedSchedule(terms: [], semesters: []);
    await controller.refreshFeatureQuery(
      FeatureId.schedule,
      const FeatureQuery(),
    );
    expect(
      controller.snapshots[FeatureId.schedule]!.timetable!.semesters,
      isEmpty,
    );
  });
}
