import 'result.dart';

class Timetable {
  const Timetable({required this.terms, required this.semesters});
  final Map<String, String> terms;
  final List<TimetableSemester> semesters;
}

class TimetableSemester {
  const TimetableSemester({
    required this.term,
    required this.weeks,
    required this.updatedAt,
  });
  final String term;
  final List<TimetableWeek> weeks;
  final String updatedAt;
}

class TimetableWeek {
  const TimetableWeek({
    required this.number,
    required this.name,
    required this.start,
    required this.end,
    required this.sections,
    required this.courses,
  });
  final int number;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final List<TimetableSection> sections;
  final List<TimetableCourse> courses;
  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return start != null &&
        end != null &&
        !day.isBefore(start!) &&
        day.isBefore(end!.add(const Duration(days: 1)));
  }
}

class TimetableSection {
  const TimetableSection(this.number, this.start, this.end);
  final int number;
  final String start;
  final String end;
}

class TimetableCourse {
  const TimetableCourse({
    required this.detail,
    this.day,
    this.begin,
    this.end,
    this.place,
    this.color,
  });
  final FeatureDetail detail;
  final int? day;
  final int? begin;
  final int? end;
  final String? place;
  final String? color;
}
