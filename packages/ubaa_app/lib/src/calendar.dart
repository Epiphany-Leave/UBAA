import 'package:ubaa_bindings/calendar.dart' as core;
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_platform/ubaa_platform.dart';

BoyaCalendarActions createBoyaCalendarActions() {
  const platform = SystemCalendar();
  return BoyaCalendarActions(
    available: platform.available,
    draft: (course, reminder) {
      String? field(String name) => course.fields
          .where((field) => field.label == name)
          .firstOrNull
          ?.value;
      final draft = core.bykcCalendarDraft(
        title: course.title,
        location: field('地点'),
        start: field('开始'),
        end: field('结束'),
        selectStart: field('选课开始'),
        reminder: reminder,
      );
      if (draft == null) return null;
      return CalendarDraft(
        title: draft.title,
        location: draft.location,
        description: draft.description,
        startMs: draft.startMs.toInt(),
        endMs: draft.endMs.toInt(),
        reminderMinutes: draft.reminderMinutes,
      );
    },
    conflicts: (draft) async {
      final events = await platform.read(draft);
      return events
          .where(
            (event) => core.calendarOverlaps(
              start: draft.startMs,
              end: draft.endMs,
              otherStart: event.startMs,
              otherEnd: event.endMs,
            ),
          )
          .toList(growable: false);
    },
    edit: platform.edit,
  );
}
