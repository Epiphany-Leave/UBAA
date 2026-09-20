import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_flutter/schedule_widget_channel.dart';

void main() {
  testWidgets('未回包的小组件启动参数不阻塞应用启动', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('cn.edu.ubaa/widget_schedule'),
            null,
          );
    });
    final pending = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cn.edu.ubaa/widget_schedule'),
          (call) => pending.future,
        );

    try {
      await ScheduleWidgetChannel().initialize();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('widget snapshot only contains timetable display fields', () {
    final snapshot = encodeScheduleWidgetSnapshot(
      Timetable(
        terms: const <String, String>{'20261': '2026 春'},
        semesters: <TimetableSemester>[
          TimetableSemester(
            term: '20261',
            updatedAt: '2026-09-10 12:00',
            weeks: <TimetableWeek>[
              TimetableWeek(
                number: 2,
                name: '第 2 周',
                start: DateTime(2026, 3, 2),
                end: DateTime(2026, 3, 8),
                sections: const <TimetableSection>[
                  TimetableSection(1, '08:00', '08:45'),
                ],
                courses: <TimetableCourse>[
                  TimetableCourse(
                    day: 1,
                    begin: 1,
                    end: 1,
                    place: '主楼 101',
                    detail: FeatureDetail(
                      title: '系统工程',
                      fields: <FeatureField>[
                        FeatureField(label: '不应导出', value: 'private'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    expect(snapshot?['schema'], 1);
    final semester =
        (snapshot?['semesters']! as List<Object?>).single
            as Map<String, Object?>;
    final week =
        (semester['weeks']! as List<Object?>).single as Map<String, Object?>;
    final course =
        (week['courses']! as List<Object?>).single as Map<String, Object?>;
    expect(week['start'], '2026-03-02');
    expect(semester['name'], '2026 春');
    expect(course, <String, Object?>{
      'title': '系统工程',
      'place': '主楼 101',
      'day': 1,
      'begin': 1,
      'end': 1,
    });
    expect(encodeScheduleWidgetSnapshot(null), isNull);
  });
}
