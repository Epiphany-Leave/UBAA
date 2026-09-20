import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_ui/ubaa_ui.dart';

void main() {
  testWidgets('设置实际更新且可恢复持久化值', (tester) async {
    Map<String, Object?>? saved;
    final settings = AppearanceSettings(
      persist: (value) async => saved = value,
    );
    await tester.pumpWidget(
      AppearanceScope(
        settings: settings,
        child: const MaterialApp(home: AppearanceSettingsPage()),
      ),
    );
    await tester.tap(find.text('显示周末'));
    await tester.pumpAndSettle();
    expect(settings.weekends, false);
    expect(saved?['weekends'], false);
    final restored = AppearanceSettings()..restore(saved!);
    expect(restored.weekends, false);
    expect(restored.timeline, true);
    restored.restore({'fontScale': 99, 'rowHeight': -10});
    expect(restored.fontScale, 1.3);
    expect(restored.rowHeight, 56);
  });
}
