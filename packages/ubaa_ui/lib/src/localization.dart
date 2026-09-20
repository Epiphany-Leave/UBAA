import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/english.dart';
import 'l10n/traditional.dart';

enum AppLanguage {
  system('system', null, '跟随系统'),
  simplified(
    'zh-Hans',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    '简体中文',
  ),
  traditional(
    'zh-Hant',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    '繁體中文',
  ),
  english('en', Locale('en'), 'English');

  const AppLanguage(this.code, this.locale, this.label);
  final String code;
  final Locale? locale;
  final String label;

  static AppLanguage fromCode(Object? code) =>
      values.firstWhere((value) => value.code == code, orElse: () => system);
}

class UbaaLocalizations {
  const UbaaLocalizations(this.locale);
  final Locale locale;
  static const supportedLocales = [
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('en'),
  ];
  static const delegates = <LocalizationsDelegate<dynamic>>[
    _Delegate(),
    ...GlobalMaterialLocalizations.delegates,
  ];

  /// Region-only Chinese locales need script resolution (Taiwan/Hong Kong/Macao).
  static Locale resolve(List<Locale>? preferred, Iterable<Locale> _) {
    for (final locale in preferred ?? const <Locale>[]) {
      if (locale.languageCode == 'en') return supportedLocales[2];
      if (locale.languageCode == 'zh') {
        final traditional =
            locale.scriptCode == 'Hant' ||
            (locale.scriptCode != 'Hans' &&
                const ['TW', 'HK', 'MO'].contains(locale.countryCode));
        return supportedLocales[traditional ? 1 : 0];
      }
    }
    return supportedLocales.first;
  }

  /// Only application-owned messages are translated. Arguments are opaque data.
  String text(String source, [List<Object?> args = const []]) {
    final catalog = locale.languageCode == 'en'
        ? englishMessages
        : locale.scriptCode == 'Hant'
        ? traditionalMessages
        : const <String, String>{};
    final template = catalog[source] ?? source;
    return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < args.length ? '${args[index] ?? ''}' : match[0]!;
    });
  }
}

class _Delegate extends LocalizationsDelegate<UbaaLocalizations> {
  const _Delegate();
  @override
  bool isSupported(Locale locale) =>
      const ['zh', 'en'].contains(locale.languageCode);
  @override
  Future<UbaaLocalizations> load(Locale locale) =>
      SynchronousFuture(UbaaLocalizations(locale));
  @override
  bool shouldReload(_Delegate old) => false;
}

extension UbaaTranslation on BuildContext {
  String weekLabel(int number, String original) =>
      Localizations.of<UbaaLocalizations>(
            this,
            UbaaLocalizations,
          )?.locale.languageCode ==
          'en'
      ? tr('第{0}周', [number])
      : original;
  String weekday(int day) =>
      Localizations.of<UbaaLocalizations>(
            this,
            UbaaLocalizations,
          )?.locale.languageCode ==
          'en'
      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1]
      : '一二三四五六日'[day - 1];

  String tr(String source, [List<Object?> args = const []]) =>
      (Localizations.of<UbaaLocalizations>(this, UbaaLocalizations) ??
              const UbaaLocalizations(Locale('zh')))
          .text(source, args);
}
