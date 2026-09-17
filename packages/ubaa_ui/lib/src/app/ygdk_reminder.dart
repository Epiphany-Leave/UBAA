part of '../widgets.dart';

class _YgdkHomeReminder extends StatefulWidget {
  const _YgdkHomeReminder({
    required this.load,
    required this.save,
    required this.onOpen,
    super.key,
  });
  final Future<bool> Function() load;
  final Future<void> Function(bool) save;
  final VoidCallback onOpen;

  @override
  State<_YgdkHomeReminder> createState() => _YgdkHomeReminderState();
}

class _YgdkHomeReminderState extends State<_YgdkHomeReminder> {
  bool? _enabled;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enabled = await widget.load();
      if (mounted) setState(() => _enabled = enabled);
    } on Object {
      if (mounted) setState(() => _error = '提醒设置读取失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(enabled);
      if (mounted) setState(() => _enabled = enabled);
    } on Object {
      if (mounted) setState(() => _error = '提醒设置保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('阳光打卡首页提醒'),
          subtitle: Text(
            _error ?? (_busy ? '正在读取或保存设置…' : '手动开启后常驻首页，不发送系统通知'),
          ),
          value: _enabled ?? false,
          onChanged: _busy || _enabled == null ? null : _save,
        ),
        if (!_busy && _enabled == null)
          TextButton(onPressed: _load, child: const Text('重试读取提醒设置')),
        if (_enabled == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('记得安排阳光打卡。是否完成请查看学校返回的记录；完成后可手动关闭提醒。'),
                TextButton.icon(
                  onPressed: widget.onOpen,
                  icon: const Icon(Icons.directions_run),
                  label: const Text('前往阳光打卡'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
