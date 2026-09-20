part of '../widgets.dart';

class _BykcCourseCard extends StatelessWidget {
  const _BykcCourseCard({required this.detail, required this.onTap});
  final FeatureDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_academicField(detail, '状态') case final status?)
                    Chip(label: Text(context.tr(_statusLabel(status)))),
                ],
              ),
              if (detail.subtitle case final teacher? when teacher.isNotEmpty)
                Text(context.tr("教师：{0}", [teacher])),
              if (_academicField(detail, '地点') case final location?)
                Text(context.tr("地点：{0}", [location])),
              if (_academicField(detail, '已选人数') case final count?)
                Text(
                  context.tr("人数：{0} / {1}", [
                    count,
                    _academicField(detail, '容量') ?? '-',
                  ]),
                ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BykcDetailSection extends StatelessWidget {
  const _BykcDetailSection({required this.title, required this.fields});
  final String title;
  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(title),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _DetailField(label: label, value: value),
            ),
        ],
      ),
    ),
  );
}

class _BykcChosenCard extends StatelessWidget {
  const _BykcChosenCard({
    required this.detail,
    this.onWrite,
    this.onSignWrite,
    this.calendar,
  });
  final BoyaCalendarActions? calendar;
  final FeatureDetail detail;
  final Future<void> Function(WriteOperation operation, int courseId)? onWrite;
  final BykcSignStarter? onSignWrite;

  @override
  Widget build(BuildContext context) {
    final deselect = detail.action<BykcDeselectAction>();
    final signIn = _sign(BykcSignKind.signIn);
    final signOut = _sign(BykcSignKind.signOut);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (detail.subtitle case final teacher? when teacher.isNotEmpty)
              Text(context.tr("教师：{0}", [teacher])),
            if (_academicField(detail, '地点') case final location?)
              Text(context.tr("地点：{0}", [location])),
            if (_academicField(detail, '课程分类') case final category?)
              Text(context.tr("分类：{0}", [category])),
            if (_academicField(detail, '开始') case final start?)
              Text(
                context.tr("时间：{0} 至 {1}", [
                  start,
                  _academicField(detail, '结束') ?? '-',
                ]),
              ),
            const SizedBox(height: 8),
            if (calendar case final actions?)
              BoyaCalendarCard(
                key: ValueKey(_academicField(detail, '课程 ID')),
                course: detail,
                actions: actions,
                selected: true,
                preview: false,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (signIn?.eligibility == ActionEligibility.allowed &&
                    onSignWrite != null)
                  FilledButton.tonal(
                    onPressed: () => onSignWrite!(signIn!),
                    child: Text(context.tr('准备签到')),
                  ),
                if (signOut?.eligibility == ActionEligibility.allowed &&
                    onSignWrite != null)
                  FilledButton.tonal(
                    onPressed: () => onSignWrite!(signOut!),
                    child: Text(context.tr('准备签退')),
                  ),
                if (deselect?.eligibility == ActionEligibility.allowed &&
                    onWrite != null)
                  OutlinedButton(
                    onPressed: () =>
                        onWrite!(deselect!.operation, deselect.courseId),
                    child: Text(context.tr('准备退选')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BykcSignAction? _sign(BykcSignKind kind) {
    for (final action in detail.actions) {
      if (action is BykcSignAction && action.kind == kind) return action;
    }
    return null;
  }
}

class _BykcStickyHeader extends SliverPersistentHeaderDelegate {
  const _BykcStickyHeader({required this.child});
  final Widget child;

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _BykcStickyHeader oldDelegate) =>
      oldDelegate.child != child;
}

class _BykcStatisticsHeader extends StatelessWidget {
  const _BykcStatisticsHeader();
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        Expanded(flex: 3, child: Text(context.tr('课程小类'))),
        Expanded(flex: 2, child: Text(context.tr('通过/指标'))),
        Expanded(flex: 2, child: Text(context.tr('达标情况'))),
      ],
    ),
  );
}

class _BykcStatisticsRow extends StatelessWidget {
  const _BykcStatisticsRow({required this.detail});
  final FeatureDetail detail;
  @override
  Widget build(BuildContext context) {
    final qualified = _academicField(detail, '达标') == '是';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.subtitle ?? detail.title),
                  if (detail.subtitle != null)
                    Text(
                      detail.title,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                context.tr("{0} / {1}", [
                  _academicField(detail, '通过数量') ?? '-',
                  _academicField(detail, '要求数量') ?? '-',
                ]),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    qualified ? Icons.check_circle : Icons.warning_amber,
                    color: qualified
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(qualified ? context.tr('达标') : context.tr('未达标')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
