import 'package:flutter/material.dart';
import 'localization.dart';

/// Local presentation preferences; no protocol or account data.
class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings({this.persist});
  final Future<void> Function(Map<String, Object?>)? persist;
  ThemeMode mode = ThemeMode.system;
  AppLanguage language = AppLanguage.system;
  int color = 0;
  double fontScale = 1;
  double rowHeight = 76;
  bool weekends = true;
  bool timeline = true;
  bool weekStrip = true;
  String? term;
  static const colors = [
    Color(0xFF536AA3),
    Color(0xFF8070AD),
    Color(0xFF247D71),
    Color(0xFFAD596D),
  ];
  Map<String, Object?> toMap() => {
    'mode': mode.index,
    'language': language.code,
    'color': color,
    'fontScale': fontScale,
    'rowHeight': rowHeight,
    'weekends': weekends,
    'timeline': timeline,
    'weekStrip': weekStrip,
    'term': term,
  };
  void restore(Map<Object?, Object?> map) {
    language = AppLanguage.fromCode(map['language']);
    mode = ThemeMode.values[(map['mode'] as num? ?? 0).toInt().clamp(0, 2)];
    color = (map['color'] as num? ?? 0).toInt().clamp(0, colors.length - 1);
    fontScale = (map['fontScale'] as num? ?? 1).toDouble().clamp(.85, 1.3);
    rowHeight = (map['rowHeight'] as num? ?? 76).toDouble().clamp(56, 110);
    weekends = map['weekends'] != false;
    timeline = map['timeline'] != false;
    weekStrip = map['weekStrip'] != false;
    term = map['term'] as String?;
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    await persist?.call(toMap());
  }

  void preview() => notifyListeners();
}

class AppearanceScope extends InheritedNotifier<AppearanceSettings> {
  const AppearanceScope({
    required AppearanceSettings settings,
    required super.child,
    super.key,
  }) : super(notifier: settings);
  static AppearanceSettings? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = AppearanceScope.of(context)!;
    Future<void> save() async {
      try {
        await settings.save();
      } catch (_) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('设置保存失败，本次生效；请重试'))),
          );
      }
    }

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Card(child: Column(children: children)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('界面与课表设置'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(context.tr('界面'), [
            ListTile(
              title: Text(context.tr('显示模式')),
              trailing: DropdownButton<ThemeMode>(
                value: settings.mode,
                items: [
                  for (final mode in ThemeMode.values)
                    DropdownMenuItem(
                      value: mode,
                      child: Text(
                        [
                          context.tr('跟随系统'),
                          context.tr('浅色'),
                          context.tr('深色'),
                        ][mode.index],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.mode = value;
                    save();
                  }
                },
              ),
            ),
            ListTile(
              title: Text(context.tr('主题色')),
              trailing: DropdownButton<int>(
                value: settings.color,
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        [
                          context.tr('雾蓝'),
                          context.tr('丁香'),
                          context.tr('青绿'),
                          context.tr('玫瑰'),
                        ][i],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.color = value;
                    save();
                  }
                },
              ),
            ),
            ListTile(
              title: Text(context.tr('字号')),
              subtitle: Text(
                context.tr("{0}% · 在系统字号基础上调整", [
                  (settings.fontScale * 100).round(),
                ]),
              ),
            ),
            Slider(
              value: settings.fontScale,
              min: .85,
              max: 1.3,
              divisions: 9,
              label: '${(settings.fontScale * 100).round()}%',
              onChanged: (value) {
                settings.fontScale = value;
                settings.preview();
              },
              onChangeEnd: (_) => save(),
            ),
          ]),
          section(context.tr('课表'), [
            SwitchListTile(
              title: Text(context.tr('显示周末')),
              value: settings.weekends,
              onChanged: (value) {
                settings.weekends = value;
                save();
              },
            ),
            SwitchListTile(
              title: Text(context.tr('显示完整时间轴')),
              value: settings.timeline,
              onChanged: (value) {
                settings.timeline = value;
                save();
              },
            ),
            SwitchListTile(
              title: Text(context.tr('显示周次缩略图')),
              value: settings.weekStrip,
              onChanged: (value) {
                settings.weekStrip = value;
                save();
              },
            ),
            ListTile(
              title: Text(context.tr('每节课高度')),
              subtitle: Text('${settings.rowHeight.round()}'),
            ),
            Slider(
              value: settings.rowHeight,
              min: 56,
              max: 110,
              divisions: 27,
              onChanged: (value) {
                settings.rowHeight = value;
                settings.preview();
              },
              onChangeEnd: (_) => save(),
            ),
            ListTile(
              leading: Icon(Icons.offline_pin_outlined),
              title: Text(context.tr('本地课表')),
              subtitle: Text(context.tr('切换学期在课表右上角菜单中；仅手动本地化时联网更新。')),
            ),
          ]),
          section(context.tr('桌面小组件'), [
            ListTile(
              title: Text(context.tr('四种课程视图')),
              subtitle: Text(
                context.tr(
                  '今日课程、近日课程跟随 App 选择的学期。一周课程和日视图可点右上角 ≡ 单独选择学期、背景和字号。',
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
