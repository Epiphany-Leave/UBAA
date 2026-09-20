import 'models.dart';

class CalendarDraft {
  const CalendarDraft({
    required this.title,
    required this.location,
    required this.description,
    required this.startMs,
    required this.endMs,
    this.reminderMinutes,
  });
  final String title, location, description;
  final int startMs, endMs;
  final int? reminderMinutes;
}

class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.location,
    required this.calendar,
    required this.startMs,
    required this.endMs,
    required this.allDay,
    required this.free,
  });
  final String title, location, calendar;
  final int startMs, endMs;
  final bool allDay, free;
}

/// UI callbacks; school parsing and overlap rules stay behind the Core bridge.
class BoyaCalendarActions {
  const BoyaCalendarActions({
    required this.available,
    required this.draft,
    required this.conflicts,
    required this.edit,
  });
  final Future<bool> Function() available;
  final CalendarDraft? Function(FeatureDetail course, bool reminder) draft;
  final Future<List<CalendarEvent>> Function(CalendarDraft draft) conflicts;

  /// Safe user message, not a provider exception or event dump.
  final Future<String> Function(CalendarDraft draft) edit;
}

class CalendarFailure implements Exception {
  const CalendarFailure(this.message);
  final String message;
}
