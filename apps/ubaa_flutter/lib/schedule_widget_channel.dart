import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_host/ubaa_host.dart';

const _scheduleWidgetChannel = MethodChannel('cn.edu.ubaa/widget_schedule');

/// Android 桌面组件的最小平台边界。
///
/// 只发送已经由 Core 解析的课表展示字段；不向 Android 保存账号、Cookie 或会话。
class ScheduleWidgetChannel {
  final ValueNotifier<OfflineScheduleTarget?> target =
      ValueNotifier<OfflineScheduleTarget?>(null);

  bool get _available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!_available) return;
    try {
      _scheduleWidgetChannel.setMethodCallHandler((call) async {
        if (call.method == 'openSchedule') _acceptTarget(call.arguments);
      });
    } on AssertionError catch (_) {
      // 注入式启动测试不会创建 Flutter binding，也不需要 Android 小组件。
      return;
    }
    // 小组件启动参数是附加入口，原生端未回包也不能阻断 Flutter 首屏。
    unawaited(_consumeLaunchTarget());
  }

  Future<void> _consumeLaunchTarget() async {
    try {
      _acceptTarget(
        await _scheduleWidgetChannel.invokeMethod<Object?>(
          'consumeLaunchTarget',
        ),
      );
    } on MissingPluginException catch (_) {
      // 小组件是可选 Android 功能，旧宿主缺少原生端时不能阻断应用启动。
    } on PlatformException catch (_) {
      // 启动参数读取失败不影响主应用；下次组件点击会再次发送目标。
    } on AssertionError catch (_) {
      // 注入式启动测试不会创建 Flutter binding，也不需要 Android 小组件。
    }
  }

  Future<void> sync(Timetable? timetable) async {
    if (!_available) return;
    await _scheduleWidgetChannel.invokeMethod<void>(
      'syncSchedule',
      encodeScheduleWidgetSnapshot(timetable),
    );
  }

  void _acceptTarget(Object? raw) {
    if (raw is! Map) return;
    final term = raw['term']?.toString().trim();
    final week = switch (raw['week']) {
      final num value => value.toInt(),
      _ => null,
    };
    if (term == null || term.isEmpty || week == null || week <= 0) return;
    target.value = OfflineScheduleTarget(term: term, week: week);
  }
}

/// 可跨 Flutter/Android 边界存储的公开课表快照。字段限于桌面展示所需内容。
Map<String, Object?>? encodeScheduleWidgetSnapshot(Timetable? timetable) {
  if (timetable == null || timetable.semesters.isEmpty) return null;
  return <String, Object?>{
    'schema': 1,
    'semesters': <Map<String, Object?>>[
      for (final semester in timetable.semesters)
        <String, Object?>{
          'term': semester.term,
          'updatedAt': semester.updatedAt,
          'weeks': <Map<String, Object?>>[
            for (final week in semester.weeks)
              <String, Object?>{
                'number': week.number,
                'name': week.name,
                'start': _widgetDate(week.start),
                'end': _widgetDate(week.end),
                'sections': <Map<String, Object?>>[
                  for (final section in week.sections)
                    <String, Object?>{
                      'number': section.number,
                      'start': section.start,
                      'end': section.end,
                    },
                ],
                'courses': <Map<String, Object?>>[
                  for (final course in week.courses)
                    <String, Object?>{
                      'title': course.detail.title,
                      'place': course.place,
                      'day': course.day,
                      'begin': course.begin,
                      'end': course.end,
                    },
                ],
              },
          ],
        },
    ],
  };
}

String? _widgetDate(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
