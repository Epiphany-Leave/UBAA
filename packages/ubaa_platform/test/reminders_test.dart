import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_platform/ubaa_platform.dart';

void main() {
  test('提醒开关默认关闭，持久化且账号隔离', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ubaa-reminder-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = directory.path;
    expect(await readYgdkHomeReminder('fixture-a', directory: path), isFalse);
    await saveYgdkHomeReminder('fixture-a', true, directory: path);
    expect(await readYgdkHomeReminder('fixture-a', directory: path), isTrue);
    expect(await readYgdkHomeReminder('fixture-b', directory: path), isFalse);
    await saveYgdkHomeReminder('fixture-a', false, directory: path);
    expect(await readYgdkHomeReminder('fixture-a', directory: path), isFalse);
  });
}
