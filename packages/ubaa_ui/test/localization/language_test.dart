import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/ubaa_ui.dart';
import 'package:ubaa_ui/src/l10n/english.dart';
import 'package:ubaa_ui/src/l10n/traditional.dart';

Widget profile({int tab = 3, Key? key}) => UbaaMainShell(
  key: key,
  user: const UserSummary(username: 'fixture'),
  snapshots: {
    for (final id in FeatureId.values)
      id: FeatureSnapshot(feature: id, status: FeatureLoadStatus.empty),
  },
  routePolicy: RoutePolicy.auto,
  telemetryEnabled: false,
  initialTab: tab,
  onRefresh: () async {},
  onRetryFeature: (_) async {},
  onLogout: () async {},
  onLogoutAndClearAccount: () async {},
  onRoutePolicyChanged: (_) {},
  onTelemetryChanged: (_) {},
);

void main() {
  testWidgets('英语和繁体中文窄屏功能入口与设置无布局溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in [
      AppLanguage.english.locale!,
      AppLanguage.traditional.locale!,
    ]) {
      for (var tab = 0; tab < 4; tab++) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: UbaaLocalizations.supportedLocales,
            localizationsDelegates: UbaaLocalizations.delegates,
            home: profile(tab: tab, key: ValueKey('$locale-$tab')),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$locale tab $tab');
      }
      await tester.pumpWidget(
        AppearanceScope(
          settings: AppearanceSettings(),
          child: MaterialApp(
            locale: locale,
            supportedLocales: UbaaLocalizations.supportedLocales,
            localizationsDelegates: UbaaLocalizations.delegates,
            home: const AppearanceSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale settings');
    }
  });
  test('系统语言解析、旧设置兼容及翻译参数保留原始数据', () {
    for (final region in ['TW', 'HK', 'MO']) {
      expect(
        UbaaLocalizations.resolve([Locale('zh', region)], []),
        AppLanguage.traditional.locale,
      );
    }
    expect(
      UbaaLocalizations.resolve([const Locale('en', 'GB')], []),
      AppLanguage.english.locale,
    );
    expect(
      UbaaLocalizations.resolve([const Locale('fr'), const Locale('en')], []),
      AppLanguage.english.locale,
    );
    expect(
      UbaaLocalizations.resolve([const Locale('fr')], []),
      AppLanguage.simplified.locale,
    );
    expect(
      UbaaLocalizations.resolve([
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'HK',
        ),
      ], []),
      AppLanguage.simplified.locale,
    );
    final settings = AppearanceSettings()..restore({'language': 'unknown'});
    expect(settings.language, AppLanguage.system);
    expect(settings.language.locale, isNull);
    expect(
      const UbaaLocalizations(Locale('en')).text('你好，{0}', ['课程统计 {1}']),
      'Hello, 课程统计 {1}',
    );
    expect(englishMessages.keys.toSet(), traditionalMessages.keys.toSet());
    final placeholders = RegExp(r'\{\d+\}');
    for (final entry in englishMessages.entries) {
      final expected = placeholders
          .allMatches(entry.key)
          .map((m) => m[0])
          .toSet();
      expect(
        placeholders.allMatches(entry.value).map((m) => m[0]).toSet(),
        expected,
        reason: entry.key,
      );
      expect(
        placeholders
            .allMatches(traditionalMessages[entry.key]!)
            .map((m) => m[0])
            .toSet(),
        expected,
        reason: entry.key,
      );
    }
  });

  testWidgets('我的提供四种语言选项', (tester) async {
    final settings = AppearanceSettings();
    await tester.pumpWidget(
      AppearanceScope(
        settings: settings,
        child: MaterialApp(home: profile()),
      ),
    );
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    for (final label in ['跟随系统', '简体中文', '繁體中文', 'English']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('切换立即生效、保存后重启可恢复、跟随系统响应语言变化', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    tester.binding.platformDispatcher.localesTestValue = [
      const Locale('zh', 'CN'),
    ];
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    Map<String, Object?>? saved;
    var settings = AppearanceSettings(persist: (value) async => saved = value);
    Widget app() => AnimatedBuilder(
      animation: settings,
      builder: (_, _) => AppearanceScope(
        settings: settings,
        child: MaterialApp(
          locale: settings.language.locale,
          supportedLocales: UbaaLocalizations.supportedLocales,
          localizationsDelegates: UbaaLocalizations.delegates,
          localeListResolutionCallback: UbaaLocalizations.resolve,
          home: profile(),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(saved?['language'], 'en');
    expect(tester.takeException(), isNull);
    settings = AppearanceSettings()..restore(saved!);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();
    expect(find.text('語言'), findsOneWidget);
    await tester.tap(find.text('語言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟隨系統'));
    await tester.pumpAndSettle();
    expect(find.text('语言'), findsOneWidget);
    tester.binding.platformDispatcher.localesTestValue = [const Locale('en')];
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(find.text('语言'), findsOneWidget);
    tester.binding.platformDispatcher.localesTestValue = [
      const Locale('zh', 'TW'),
    ];
    await tester.pumpAndSettle();
    expect(find.text('语言'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
