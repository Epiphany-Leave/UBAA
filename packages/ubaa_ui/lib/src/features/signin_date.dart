part of '../widgets.dart';

class _SigninDateHeader extends StatefulWidget {
  const _SigninDateHeader({
    required this.query,
    required this.onQuery,
    required this.busy,
    required this.snapshot,
    this.timetable,
  });
  final FeatureQuery query;
  final Future<void> Function(FeatureQuery) onQuery;
  final bool busy;
  final FeatureSnapshot snapshot;
  final Timetable? timetable;

  @override
  State<_SigninDateHeader> createState() => _SigninDateHeaderState();
}

class _SigninDateHeaderState extends State<_SigninDateHeader> {
  List<SigninDisplayStatus>? courses(DateTime date) {
    for (final day in widget.snapshot.signinDays) {
      if (day.date == date) return day.courses;
    }
    final weeks = widget.timetable?.semesters.expand((s) => s.weeks);
    if (weeks == null) return null;
    for (final week in weeks) {
      if (week.contains(date)) {
        return [
          for (final course in week.courses)
            if (course.day == date.weekday) SigninDisplayStatus.unknown,
        ];
      }
    }
    return null;
  }

  void select(DateTime date) => unawaited(
    widget.onQuery(widget.query.copyWith(date: date, refresh: false)),
  );

  @override
  Widget build(BuildContext context) {
    final now =
        widget.query.date ??
        DateTime.now().toUtc().add(const Duration(hours: 8));
    final date = DateTime(now.year, now.month, now.day);
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                IconButton(
                  tooltip: '上一周',
                  onPressed: widget.busy
                      ? null
                      : () => select(date.subtract(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text('${date.year}年${date.month}月'),
                    onPressed: widget.busy
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null && mounted) select(picked);
                          },
                  ),
                ),
                IconButton(
                  tooltip: '下一周',
                  onPressed: widget.busy
                      ? null
                      : () => select(date.add(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: '刷新签到状态',
                  onPressed: widget.busy
                      ? null
                      : () => unawaited(
                          widget.onQuery(
                            widget.query.copyWith(date: date, refresh: true),
                          ),
                        ),
                  icon: const Icon(Icons.refresh),
                ),
                PopupMenuButton<FeatureQueryView>(
                  tooltip: context.tr('筛选'),
                  enabled: !widget.busy,
                  initialValue: widget.query.view,
                  icon: const Icon(Icons.tune),
                  onSelected: (view) => unawaited(
                    widget.onQuery(
                      widget.query.copyWith(
                        date: date,
                        view: view,
                        refresh: false,
                      ),
                    ),
                  ),
                  itemBuilder: (context) => [
                    for (final entry in const {
                      FeatureQueryView.summary: '全部课程',
                      FeatureQueryView.signinPending: '未签到',
                      FeatureQueryView.signinCompleted: '已签到',
                    }.entries)
                      CheckedPopupMenuItem(
                        value: entry.key,
                        checked: entry.key == widget.query.view,
                        child: Text(context.tr(entry.value)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: dayCard(context, monday.add(Duration(days: i)), date),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final status in SigninDisplayStatus.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _signinDot(status),
                    const SizedBox(width: 4),
                    Text(
                      _signinLabel(status),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '北京时间 · 开课前 10 分钟开放；刷新更新整周',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (widget.snapshot.updatedAt case final time?)
            Text(
              '数据时间：${time.toLocal().toString().split('.').first}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }

  Widget dayCard(BuildContext context, DateTime day, DateTime selected) {
    final states = courses(day);
    final active = day == selected;
    final colors = Theme.of(context).colorScheme;
    final label =
        '${day.month}/${day.day}，${states == null ? '课程待查询' : '${states.length}门课程'}';
    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: Tooltip(
        message:
            '$label${widget.snapshot.signinDays.any((value) => value.date == day) ? '（本地签到快照）' : '（课表，签到状态待查询）'}${(states?.length ?? 0) > 12 ? '，圆点仅显示前12门' : ''}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: active
                ? colors.primaryContainer
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: ValueKey('signin-day-${day.year}-${day.month}-${day.day}'),
              borderRadius: BorderRadius.circular(12),
              onTap: widget.busy ? null : () => select(day),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 106),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 3,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '一二三四五六日'[day.weekday - 1],
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        states == null ? '待查' : '${states.length}门',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      for (var row = 0; row < 3; row++)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var column = 0; column < 4; column++)
                              SizedBox(
                                width: 8,
                                height: 9,
                                child: Center(
                                  child:
                                      row * 4 + column < (states?.length ?? 0)
                                      ? _signinDot(
                                          states![row * 4 + column],
                                          size: 6,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _signinLabel(SigninDisplayStatus status) => switch (status) {
  SigninDisplayStatus.pending => '未签到',
  SigninDisplayStatus.signed => '已签到',
  SigninDisplayStatus.late => '迟到',
  SigninDisplayStatus.unknown => '待查/未知',
};

Widget _signinDot(SigninDisplayStatus status, {double size = 7}) => Tooltip(
  message: _signinLabel(status),
  child: Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: switch (status) {
        SigninDisplayStatus.pending => Colors.red,
        SigninDisplayStatus.signed => Colors.green,
        SigninDisplayStatus.late => Colors.amber,
        SigninDisplayStatus.unknown => Colors.grey,
      },
    ),
  ),
);
