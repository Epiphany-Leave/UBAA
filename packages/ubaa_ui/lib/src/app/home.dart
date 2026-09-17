part of '../widgets.dart';

class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.user,
    required this.snapshots,
    required this.onFeatureTap,
    required this.onAllFeatures,
    required this.onRefresh,
    this.gradeChangeCount = 0,
    this.onDismissGradeChanges,
    this.onLoadYgdkReminder,
    this.onSaveYgdkReminder,
  });

  final UserSummary? user;
  final Map<FeatureId, FeatureSnapshot> snapshots;
  final ValueChanged<FeatureId> onFeatureTap;
  final VoidCallback onAllFeatures;
  final Future<void> Function() onRefresh;
  final int gradeChangeCount;
  final VoidCallback? onDismissGradeChanges;
  final Future<bool> Function()? onLoadYgdkReminder;
  final Future<void> Function(bool)? onSaveYgdkReminder;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final colors = Theme.of(context).colorScheme;
    final schedule =
        snapshots[FeatureId.schedule] ??
        const FeatureSnapshot(feature: FeatureId.schedule);
    final exam =
        snapshots[FeatureId.exam] ??
        const FeatureSnapshot(feature: FeatureId.exam);
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        exam.details.where((detail) {
          final date = DateTime.tryParse(_academicField(detail, '考试日期') ?? '');
          return date != null && !date.isBefore(today);
        }).toList()..sort(
          (a, b) => (_academicField(a, '考试日期') ?? '').compareTo(
            _academicField(b, '考试日期') ?? '',
          ),
        );
    final undated = exam.details
        .where(
          (detail) =>
              DateTime.tryParse(_academicField(detail, '考试日期') ?? '') == null,
        )
        .length;
    final hasSemester =
        schedule.timetable?.semesters.isNotEmpty == true ||
        schedule.details.isNotEmpty;
    final cards = <Widget>[
      _HomeSummaryCard(
        title: '今日课程',
        action: '课表查询',
        icon: Icons.today_outlined,
        highlighted: true,
        onTap: () => onFeatureTap(FeatureId.schedule),
        children: [
          if (schedule.status == FeatureLoadStatus.loading)
            const LinearProgressIndicator(),
          if (schedule.status == FeatureLoadStatus.stale)
            const Text('刷新失败，仍显示已保存课表'),
          if (schedule.details.isNotEmpty)
            for (final course in schedule.details.take(3))
              _HomeEventRow(
                detail: course,
                time: [
                  _academicField(course, '开始时间'),
                  _academicField(course, '结束时间'),
                ].whereType<String>().join('–'),
              )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(switch (schedule.status) {
                FeatureLoadStatus.loading => '正在读取课表…',
                FeatureLoadStatus.failure => '课表暂未加载，请进入课表查询重试',
                FeatureLoadStatus.idle => '打开课表，导入本学期课程',
                _ => hasSemester ? '今天没有课程' : '还没有保存课表，点击导入',
              }),
            ),
          if (schedule.details.length > 3)
            Text('另有 ${schedule.details.length - 3} 门课程，进入课表查看'),
        ],
      ),
      _HomeSummaryCard(
        title: '近期考试',
        action: '考试查询',
        icon: Icons.event_note_outlined,
        onTap: () => onFeatureTap(FeatureId.exam),
        children: [
          if (exam.status == FeatureLoadStatus.loading)
            const LinearProgressIndicator(),
          if (exam.status == FeatureLoadStatus.stale)
            const Text('刷新失败，仍显示上次考试信息'),
          for (final detail in upcoming.take(2))
            _HomeEventRow(
              detail: detail,
              time: [
                _academicField(detail, '考试日期'),
                _academicField(detail, '时间'),
              ].whereType<String>().join(' · '),
            ),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(switch (exam.status) {
                FeatureLoadStatus.loading => '正在查询考试安排…',
                FeatureLoadStatus.failure => '考试查询失败，点击查看详情并重试',
                FeatureLoadStatus.idle => '点击查看考试安排',
                _ => undated > 0 ? '考试时间待定，请查看详情' : '当前已加载记录中没有近期考试',
              }),
            ),
          if (upcoming.isNotEmpty && undated > 0) Text('另有 $undated 项时间待定'),
          if (upcoming.length > 2) Text('另有 ${upcoming.length - 2} 场考试，点击查看'),
        ],
      ),
    ];
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你好，${user?.preferredName ?? '同学'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${now.month}月${now.day}日 · 星期${'一二三四五六日'[now.weekday - 1]}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (onLoadYgdkReminder != null &&
                    onSaveYgdkReminder != null) ...[
                  _YgdkHomeReminder(
                    key: ValueKey(user?.username),
                    load: onLoadYgdkReminder!,
                    save: onSaveYgdkReminder!,
                    onOpen: () => onFeatureTap(FeatureId.ygdk),
                  ),
                  const SizedBox(height: 12),
                ],
                if (gradeChangeCount > 0) ...[
                  Card(
                    color: colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '最近刷新发现 $gradeChangeCount 门课程成绩更新',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Text('本次登录期间的变化，前往成绩查询查看。'),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () {
                                  onDismissGradeChanges?.call();
                                  onFeatureTap(FeatureId.grades);
                                },
                                child: const Text('查看成绩'),
                              ),
                              TextButton(
                                onPressed: onDismissGradeChanges,
                                child: const Text('忽略'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: cards[1]),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 14),
                        cards[1],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '常用功能',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: onAllFeatures,
                      child: const Text('全部功能'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final feature in [
                        FeatureId.grades,
                        FeatureId.bykc,
                        FeatureId.classroom,
                        FeatureId.libbook,
                      ])
                        SizedBox(
                          width:
                              (constraints.maxWidth -
                                  8 * (constraints.maxWidth >= 340 ? 3 : 1)) /
                              (constraints.maxWidth >= 340 ? 4 : 2),
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => onFeatureTap(feature),
                            child: Column(
                              children: [
                                Icon(_featureIcon(feature)),
                                const SizedBox(height: 10),
                                Text(
                                  feature.title,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeEventRow extends StatelessWidget {
  const _HomeEventRow({required this.detail, required this.time});
  final FeatureDetail detail;
  final String time;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 44,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (time.isNotEmpty)
                Text(time, style: Theme.of(context).textTheme.labelMedium),
              Text(detail.title, style: Theme.of(context).textTheme.titleSmall),
              if (_academicField(detail, '地点') case final place?)
                Text(place, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    required this.title,
    required this.action,
    required this.icon,
    required this.onTap,
    required this.children,
    this.highlighted = false,
  });
  final String title;
  final String action;
  final IconData icon;
  final VoidCallback onTap;
  final List<Widget> children;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: highlighted
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerLow,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...children,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onTap,
                label: Text(action),
                icon: const Icon(Icons.arrow_forward, size: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeatureGridView extends StatelessWidget {
  const _FeatureGridView({
    required this.snapshots,
    required this.onFeatureTap,
    required this.onRetryFeature,
  });

  final Map<FeatureId, FeatureSnapshot> snapshots;
  final ValueChanged<FeatureId> onFeatureTap;
  final Future<void> Function(FeatureId) onRetryFeature;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: <Widget>[
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: _FeatureGridSliver(
          snapshots: snapshots,
          onFeatureTap: onFeatureTap,
          onRetryFeature: onRetryFeature,
        ),
      ),
    ],
  );
}

class _FeatureGridSliver extends StatelessWidget {
  const _FeatureGridSliver({
    required this.snapshots,
    required this.onFeatureTap,
    required this.onRetryFeature,
    this.features = ordinaryFeatureIds,
  });

  final Map<FeatureId, FeatureSnapshot> snapshots;
  final ValueChanged<FeatureId> onFeatureTap;
  final Future<void> Function(FeatureId) onRetryFeature;
  final List<FeatureId> features;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 360,
      mainAxisExtent: 160,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemCount: features.length,
    itemBuilder: (context, index) {
      final feature = features[index];
      return _FeatureCard(
        feature: feature,
        snapshot: snapshots[feature]!,
        onTap: () => onFeatureTap(feature),
        onRetry: () => onRetryFeature(feature),
      );
    },
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.feature,
    required this.snapshot,
    required this.onTap,
    required this.onRetry,
  });

  final FeatureId feature;
  final FeatureSnapshot snapshot;
  final VoidCallback onTap;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFailure = snapshot.status == FeatureLoadStatus.failure;
    final isStale = snapshot.status == FeatureLoadStatus.stale;
    return Semantics(
      container: true,
      button: true,
      label: '$featureLabel：${_statusText(snapshot)}。点击查看详情',
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      _featureIcon(feature),
                      size: 40,
                      color: colorScheme.primary,
                    ),
                    const Spacer(),
                    if (snapshot.status == FeatureLoadStatus.loading)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (isFailure || isStale)
                      IconButton(
                        tooltip: '重试',
                        onPressed: () => onRetry(),
                        icon: Icon(Icons.refresh, color: colorScheme.error),
                      )
                    else if (snapshot.status == FeatureLoadStatus.success)
                      Icon(Icons.check_circle, color: colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  feature.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    _statusText(snapshot),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isFailure
                          ? colorScheme.error
                          : isStale
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  feature.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get featureLabel => feature.title;

  String _statusText(FeatureSnapshot snapshot) => switch (snapshot.status) {
    FeatureLoadStatus.idle => feature.description,
    FeatureLoadStatus.loading => '正在加载…',
    FeatureLoadStatus.success => snapshot.summary ?? '已加载，点击查看详情',
    FeatureLoadStatus.empty => '暂无数据',
    FeatureLoadStatus.stale => '${snapshot.summary ?? '已显示上次数据'}（刷新失败，可重试）',
    FeatureLoadStatus.failure => snapshot.error?.message ?? '加载失败，请重试',
  };
}

class _AdvancedFeaturesView extends StatelessWidget {
  const _AdvancedFeaturesView({
    required this.snapshots,
    required this.onFeatureTap,
    required this.onRetryFeature,
  });

  final Map<FeatureId, FeatureSnapshot> snapshots;
  final ValueChanged<FeatureId> onFeatureTap;
  final Future<void> Function(FeatureId) onRetryFeature;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: <Widget>[
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: _FeatureGridSliver(
          features: advancedFeatureIds,
          snapshots: snapshots,
          onFeatureTap: onFeatureTap,
          onRetryFeature: onRetryFeature,
        ),
      ),
    ],
  );
}

IconData _featureIcon(FeatureId feature) => switch (feature) {
  FeatureId.schedule => Icons.calendar_today,
  FeatureId.exam => Icons.assignment_outlined,
  FeatureId.grades => Icons.grade,
  FeatureId.bykc => Icons.school,
  FeatureId.classroom => Icons.meeting_room,
  FeatureId.spoc => Icons.assignment_turned_in,
  FeatureId.judge => Icons.code,
  FeatureId.libbook => Icons.event_seat,
  FeatureId.signin => Icons.how_to_reg,
  FeatureId.cgyy => Icons.sports_gymnastics,
  FeatureId.ygdk => Icons.wb_sunny,
  FeatureId.evaluation => Icons.assignment_turned_in,
};
