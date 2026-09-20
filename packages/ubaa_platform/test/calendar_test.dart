import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_platform/ubaa_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('calendar-test');
  const calendar = SystemCalendar(channel: channel);
  const draft = CalendarDraft(
    title: '测试课程',
    location: '教室',
    description: '',
    startMs: 100,
    endMs: 200,
    reminderMinutes: 5,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('unavailable host hides calendar capability', () async {
    expect(await calendar.available(), isFalse);
  });
  test(
    'denied permission never reads events; independent editor still works',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'calendar.requestRead' ? false : 'opened';
      });
      await expectLater(calendar.read(draft), throwsA(isA<CalendarFailure>()));
      expect(calls, ['calendar.requestRead']);
      expect(await calendar.edit(draft), contains('确认提前 5 分钟'));
    },
  );
  test(
    'provider failure and malformed response cannot become no conflicts',
    () async {
      for (final response in [
        null,
        [
          {'startMs': 10, 'endMs': 0},
        ],
      ]) {
        messenger.setMockMethodCallHandler(
          channel,
          (call) async =>
              call.method == 'calendar.requestRead' ? true : response,
        );
        await expectLater(
          calendar.read(draft),
          throwsA(isA<CalendarFailure>()),
        );
      }
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'calendar.requestRead') return true;
        throw PlatformException(code: 'denied', message: 'private event title');
      });
      try {
        await calendar.read(draft);
        fail('must fail');
      } on CalendarFailure catch (error) {
        expect(error.message, isNot(contains('private')));
      }
    },
  );
  test(
    'edit cancellation is never claimed saved and never requests read access',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'calendar.edit');
        expect((call.arguments as Map)['reminderMinutes'], 5);
        return 'cancelled';
      });
      expect(await calendar.edit(draft), '已取消添加日程。');
    },
  );
  test(
    'all-day recurring instances retain provider times and free marker',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'calendar.requestRead'
            ? true
            : [
                {
                  'title': '测试日程',
                  'location': '地点',
                  'calendar': '个人日历',
                  'startMs': 50,
                  'endMs': 250,
                  'allDay': true,
                  'free': true,
                },
              ],
      );
      final events = await calendar.read(draft);
      expect(events.single.calendar, '个人日历');
      expect(events.single.allDay, isTrue);
      expect(events.single.free, isTrue);
    },
  );
}
