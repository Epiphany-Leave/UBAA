part of '../widgets.dart';

/// The state owns calendar results only while this course is visible.
class BoyaCalendarCard extends StatefulWidget {
  const BoyaCalendarCard({
    required this.course,
    required this.actions,
    required this.selected,
    required this.preview,
    super.key,
  });
  final FeatureDetail course;
  final BoyaCalendarActions actions;
  final bool selected, preview;

  @override
  State<BoyaCalendarCard> createState() => _BoyaCalendarCardState();
}

class _BoyaCalendarCardState extends State<BoyaCalendarCard>
    with WidgetsBindingObserver {
  bool _available = false, _busy = false;
  int _generation = 0;
  String? _message;
  List<CalendarEvent>? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _probe();
  }

  Future<void> _probe() async {
    final available = await widget.actions.available();
    if (mounted) setState(() => _available = available);
  }

  @override
  void didUpdateWidget(covariant BoyaCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course != widget.course) {
      _generation++;
      _events = null;
      _message = null;
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Clear personal details before backgrounding; request/query rechecks permissions.
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => _events = null);
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _generation++;
      _busy = false;
      _message = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    _events = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _run({bool check = false, bool reminder = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _message = null;
      _events = null;
    });
    try {
      final draft = widget.actions.draft(widget.course, reminder);
      if (draft == null) {
        throw const CalendarFailure('缺少有效时间，无法检测或添加日程。');
      }
      if (check) {
        final events = await widget.actions.conflicts(draft);
        if (!mounted || generation != _generation) return;
        setState(() {
          _events = events;
          _message = events.isEmpty
              ? '可读取的手机日历中未发现重叠日程。'
              : '发现 ${events.length} 项重叠日程，请自行决定是否选课。';
        });
      } else {
        final message = await widget.actions.edit(draft);
        if (!mounted || generation != _generation) return;
        setState(() => _message = message);
      }
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _message = error is CalendarFailure
            ? error.message
            : '日历操作未完成，请重试；不影响选课。',
      );
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('手机日历', style: Theme.of(context).textTheme.titleMedium),
            const Text('检测时读取手机日历（包含个人安排），仅在设备上处理。保存由系统日历确认，可能同步到你选择的日历账户。'),
            if (widget.preview) const Text('选课提醒：请在日历编辑页确认提前 5 分钟提醒并保存。'),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : () => _run(check: true),
                  icon: const Icon(Icons.event_available),
                  label: const Text('检测日程冲突'),
                ),
                if (widget.selected)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _run(),
                    icon: const Icon(Icons.event_note),
                    label: const Text('添加课程日程'),
                  ),
                if (widget.preview && !widget.selected)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _run(reminder: true),
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('添加选课提醒'),
                  ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message case final message?) Text(message),
            for (final event in _events ?? const <CalendarEvent>[])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${event.title}${event.free ? '（标记为空闲）' : ''}'),
                subtitle: Text(
                  '${_time(event.startMs)} 至 ${_time(event.endMs)}${event.allDay ? ' · 全天' : ''}\n'
                  '${event.calendar}${event.location.isEmpty ? '' : ' · ${event.location}'}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _time(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }
}
