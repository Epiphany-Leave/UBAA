part of '../widgets.dart';

class _SearchableAcademicList extends StatefulWidget {
  const _SearchableAcademicList({required this.details, required this.builder});
  final List<FeatureDetail> details;
  final Widget Function(List<FeatureDetail>) builder;

  @override
  State<_SearchableAcademicList> createState() =>
      _SearchableAcademicListState();
}

class _SearchableAcademicListState extends State<_SearchableAcademicList> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final details = query.isEmpty
        ? widget.details
        : widget.details
              .where((detail) {
                final text = [
                  detail.title,
                  detail.subtitle ?? '',
                  for (final field in detail.fields)
                    '${field.label} ${field.value}',
                ].join(' ').toLowerCase();
                return text.contains(query);
              })
              .toList(growable: false);
    return Stack(
      children: [
        Positioned.fill(child: widget.builder(details)),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton(
            tooltip: context.tr('搜索当前结果'),
            onPressed: _showSearch,
            child: const Icon(Icons.search),
          ),
        ),
      ],
    );
  }

  Future<void> _showSearch() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('搜索当前结果')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.tr('输入课程、考试或其他内容')),
        onChanged: (value) => setState(() => _query = value),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _controller.clear();
            setState(() => _query = '');
            Navigator.pop(context);
          },
          child: Text(context.tr('清除')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('完成')),
        ),
      ],
    ),
  );
}

extension _AcademicQueryControls on _FeatureQueryControlsState {
  List<Widget> _academicQueryFields(StateSetter setState) => <Widget>[
    if (widget.feature == FeatureId.schedule) ..._scheduleControls(),
    if (widget.feature == FeatureId.exam)
      DropdownButton<FeatureQueryView>(
        value: _examView,
        onChanged: _submitting
            ? null
            : (value) =>
                  setState(() => _examView = value ?? FeatureQueryView.summary),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('全部考试')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.examArranged,
            child: Text(context.tr('已安排')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.examNotArranged,
            child: Text(context.tr('未安排')),
          ),
        ],
      ),
    if (widget.feature == FeatureId.grades)
      DropdownButton<FeatureQueryView>(
        value: _gradesView,
        onChanged: _submitting
            ? null
            : (value) => setState(
                () => _gradesView = value ?? FeatureQueryView.summary,
              ),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('全部成绩')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.gradesScored,
            child: Text(context.tr('已出成绩')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.gradesMissing,
            child: Text(context.tr('待出成绩')),
          ),
        ],
      ),
    if (widget.feature == FeatureId.exam ||
        widget.feature == FeatureId.grades) ...<Widget>[
      SizedBox(
        width: 180,
        child: TextField(
          controller: _termController,
          decoration: InputDecoration(
            labelText: context.tr('学期编码（可选）'),
            hintText: widget.feature == FeatureId.grades
                ? context.tr('研究生留空查看全部学期')
                : context.tr('留空使用当前学期'),
            isDense: true,
          ),
        ),
      ),
    ],
    if (widget.feature == FeatureId.classroom) ...<Widget>[
      SizedBox(
        width: 150,
        child: TextField(
          controller: _dateController,
          decoration: InputDecoration(
            labelText: context.tr('日期'),
            hintText: 'YYYY-MM-DD',
            isDense: true,
          ),
        ),
      ),
      SizedBox(
        width: 130,
        child: TextField(
          controller: _floorController,
          decoration: InputDecoration(
            labelText: context.tr('楼层（可选）'),
            hintText: context.tr('如 F2'),
            isDense: true,
          ),
        ),
      ),
      SizedBox(
        width: 130,
        child: TextField(
          controller: _sectionController,
          decoration: InputDecoration(
            labelText: context.tr('节次（可选）'),
            hintText: context.tr('如 3'),
            isDense: true,
          ),
        ),
      ),
      DropdownButton<int>(
        value: _campus,
        onChanged: _submitting
            ? null
            : (value) => setState(() => _campus = value ?? 1),
        items: <DropdownMenuItem<int>>[
          DropdownMenuItem(value: 1, child: Text(context.tr('校区 1'))),
          DropdownMenuItem(value: 2, child: Text(context.tr('校区 2'))),
          DropdownMenuItem(value: 3, child: Text(context.tr('校区 3'))),
        ],
      ),
    ],
  ];
  List<Widget> _scheduleControls() {
    final nav = widget.scheduleNavigation;
    if (nav == null) {
      return [
        FilledButton(
          onPressed: _submitting ? null : () => _showWeek(),
          child: Text(
            _submitting ? context.tr('正在加载课表…') : context.tr('查看本周课表'),
          ),
        ),
      ];
    }
    final weeks = nav.weeks.keys.toList()..sort();
    final index = weeks.indexOf(nav.week);
    return [
      DropdownButton<String>(
        value: nav.term,
        items: nav.terms.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: _submitting ? null : (term) => _showWeek(term: term),
      ),
      IconButton(
        tooltip: context.tr('上一周'),
        icon: const Icon(Icons.chevron_left),
        onPressed: _submitting || index <= 0
            ? null
            : () => _showWeek(term: nav.term, week: weeks[index - 1]),
      ),
      DropdownButton<int>(
        value: nav.week,
        items: weeks
            .map(
              (week) =>
                  DropdownMenuItem(value: week, child: Text(nav.weeks[week]!)),
            )
            .toList(),
        onChanged: _submitting
            ? null
            : (week) => _showWeek(term: nav.term, week: week),
      ),
      IconButton(
        tooltip: context.tr('下一周'),
        icon: const Icon(Icons.chevron_right),
        onPressed: _submitting || index < 0 || index >= weeks.length - 1
            ? null
            : () => _showWeek(term: nav.term, week: weeks[index + 1]),
      ),
      TextButton(
        onPressed: _submitting ? null : () => _showWeek(),
        child: Text(context.tr('回到本周')),
      ),
    ];
  }
}

class _ExamList extends StatelessWidget {
  const _ExamList({required this.details});

  final List<FeatureDetail> details;

  @override
  Widget build(BuildContext context) {
    final arranged = <FeatureDetail>[];
    final notArranged = <FeatureDetail>[];
    for (final detail in details) {
      if (_academicField(detail, '安排状态') == '未安排') {
        notArranged.add(detail);
      } else {
        arranged.add(detail);
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        ..._examSection(context, '已安排考试', arranged),
        ..._examSection(context, '未安排考试', notArranged),
      ],
    );
  }
}

List<Widget> _examSection(
  BuildContext context,
  String title,
  List<FeatureDetail> details,
) {
  if (details.isEmpty) return const <Widget>[];
  final grouped = <String, List<FeatureDetail>>{};
  for (final detail in details) {
    final date = _academicField(detail, '考试日期') ?? '时间待定';
    grouped.putIfAbsent(date, () => <FeatureDetail>[]).add(detail);
  }
  final dates = grouped.keys.toList()..sort();
  return <Widget>[
    Text(context.tr(title), style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    for (final date in dates) ...<Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(date, style: Theme.of(context).textTheme.labelLarge),
      ),
      for (final detail in grouped[date]!)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  const SizedBox(height: 20),
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: VerticalDivider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(child: _ExamCompactCard(detail: detail)),
            ],
          ),
        ),
    ],
    const SizedBox(height: 12),
  ];
}

class _ExamCompactCard extends StatelessWidget {
  const _ExamCompactCard({required this.detail});
  final FeatureDetail detail;

  @override
  Widget build(BuildContext context) {
    final seat = _academicField(detail, '座位');
    final place = _academicField(detail, '地点');
    final time = _academicField(detail, '时间') ?? detail.subtitle ?? '时间待公布';
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('考试详情')),
            content: SingleChildScrollView(
              child: _AcademicDetailCard(detail: detail),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('关闭')),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (seat != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(context.tr("座位 {0}", [seat])),
                ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(time)),
                ],
              ),
              if (place != null) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(place)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GradesList extends StatelessWidget {
  const _GradesList({required this.details});

  final List<FeatureDetail> details;

  @override
  Widget build(BuildContext context) {
    final statistics = details
        .where((detail) => _academicField(detail, 'GPA') != null)
        .toList(growable: false);
    final courses = details
        .where((detail) => !statistics.contains(detail))
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        if (statistics.isNotEmpty) ...<Widget>[
          Text(
            context.tr('成绩统计'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(context.tr('GPA 与加权均分由成绩规则计算。')),
          ),
          for (final detail in statistics) _GradeStatisticsCard(detail: detail),
          const SizedBox(height: 12),
        ],
        if (courses.isNotEmpty)
          Text(
            context.tr('课程成绩'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        for (final detail in courses) _GradeCourseCard(detail: detail),
      ],
    );
  }
}

class _GradeStatisticsCard extends StatelessWidget {
  const _GradeStatisticsCard({required this.detail});
  final FeatureDetail detail;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final field in detail.fields)
                  SizedBox(
                    width: constraints.maxWidth < 240
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.value,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          context.tr(field.label),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _GradeCourseCard extends StatelessWidget {
  const _GradeCourseCard({required this.detail});
  final FeatureDetail detail;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.only(top: 8, bottom: 4),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('成绩详情')),
          content: SingleChildScrollView(
            child: _AcademicDetailCard(detail: detail),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('关闭')),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.menu_book_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    detail.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _academicField(detail, '成绩') ?? context.tr('待出'),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (detail.subtitle case final subtitle?
                when subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
            for (final field in detail.fields)
              if (const {
                '学分',
                '绩点',
                '课程类型',
                '成绩制',
                '学期',
              }.contains(field.label)) ...[
                const SizedBox(height: 6),
                Text('${context.tr(field.label)}：${field.value}'),
              ],
          ],
        ),
      ),
    ),
  );
}

class _AcademicDetailCard extends StatelessWidget {
  const _AcademicDetailCard({required this.detail});

  final FeatureDetail detail;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  detail.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (detail.subtitle case final subtitle?
              when subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
          for (final field in detail.fields) ...<Widget>[
            const SizedBox(height: 8),
            _DetailField(label: field.label, value: field.value),
          ],
        ],
      ),
    ),
  );
}

String? _academicField(FeatureDetail detail, String label) {
  for (final field in detail.fields) {
    if (field.label == label && field.value.trim().isNotEmpty) {
      return field.value;
    }
  }
  return null;
}
