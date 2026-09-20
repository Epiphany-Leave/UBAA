import 'package:flutter/services.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

/// Native calendar access is optional and never enters diagnostics or storage.
class SystemCalendar {
  const SystemCalendar({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('cn.edu.buaa.ubaa/platform');
  final MethodChannel _channel;

  Future<bool> available() async {
    try {
      return await _channel.invokeMethod<bool>('calendar.capability') == true;
    } on Object {
      return false;
    }
  }

  Future<List<CalendarEvent>> read(CalendarDraft draft) async {
    try {
      if (await _channel.invokeMethod<bool>('calendar.requestRead') != true) {
        throw const CalendarFailure('未获得日历读取权限，未完成检测。可在系统设置中授权后重试。');
      }
      final rows = await _channel.invokeListMethod<dynamic>('calendar.read', {
        'startMs': draft.startMs,
        'endMs': draft.endMs,
      });
      if (rows == null) throw const FormatException();
      return rows
          .map((value) {
            final row = value as Map;
            final start = row['startMs'] as int;
            final end = row['endMs'] as int;
            if (end <= start) throw const FormatException();
            return CalendarEvent(
              title: row['title'] as String,
              location: row['location'] as String,
              calendar: row['calendar'] as String,
              startMs: start,
              endMs: end,
              allDay: row['allDay'] as bool,
              free: row['free'] as bool,
            );
          })
          .toList(growable: false);
    } on CalendarFailure {
      rethrow;
    } on Object {
      throw const CalendarFailure('日历读取失败，未完成检测。请检查权限后重试。');
    }
  }

  Future<String> edit(CalendarDraft draft) async {
    try {
      final result = await _channel.invokeMethod<String>('calendar.edit', {
        'title': draft.title,
        'location': draft.location,
        'description': draft.description,
        'startMs': draft.startMs,
        'endMs': draft.endMs,
        'reminderMinutes': draft.reminderMinutes,
      });
      return switch (result) {
        'saved' => '已保存到系统日历。',
        'cancelled' => '已取消添加日程。',
        'opened' =>
          draft.reminderMinutes != null
              ? '已打开系统日历，请确认提前 5 分钟提醒并保存。'
              : '已打开系统日历，请确认并保存。',
        _ => throw const CalendarFailure('未能确认日历操作结果，请在系统日历中检查。'),
      };
    } on CalendarFailure {
      rethrow;
    } on Object {
      throw const CalendarFailure('无法打开系统日历，请检查日历应用或权限后重试。');
    }
  }
}
