part of '../widgets.dart';

class TimetableView extends StatefulWidget {
  const TimetableView({
    required this.snapshot,
    required this.onQuery,
    this.offline = false,
    this.initialTerm,
    this.initialWeek,
    super.key,
  });
  final FeatureSnapshot snapshot;
  final Future<void> Function(FeatureQuery) onQuery;
  final bool offline;
  final String? initialTerm;
  final int? initialWeek;
  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  PageController? _pages;
  final ScrollController _weekStrip = ScrollController();
  String? _term;
  int _index = 0;
  bool _initialTargetPending = true;
  List<TimetableSemester> get _semesters =>
      widget.snapshot.timetable?.semesters ?? [];
  TimetableSemester? get _semester =>
      _semesters.where((s) => s.term == _term).firstOrNull;
  @override
  void initState() {
    super.initState();
    _reset();
    if (!widget.offline && _semesters.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _semesters.isEmpty && !widget.offline) {
          widget.onQuery(
            const FeatureQuery(view: FeatureQueryView.scheduleWeek),
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant TimetableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTerm != widget.initialTerm ||
        oldWidget.initialWeek != widget.initialWeek) {
      _initialTargetPending = true;
    }
    if (!identical(oldWidget.snapshot.timetable, widget.snapshot.timetable))
      _reset();
  }

  void _reset() {
    final requestedTerm = _initialTargetPending ? widget.initialTerm : null;
    final requestedWeek = _initialTargetPending ? widget.initialWeek : null;
    _initialTargetPending = false;
    final oldNumber = _index < 0
        ? null
        : _semester?.weeks.elementAtOrNull(_index)?.number;
    final fallbackTerm =
        _semester?.term ??
        _semesters
            .where((s) => s.weeks.any((w) => w.contains(DateTime.now())))
            .firstOrNull
            ?.term ??
        _semesters.firstOrNull?.term;
    _term = _semesters.any((semester) => semester.term == requestedTerm)
        ? requestedTerm
        : fallbackTerm;
    final weeks = _semester?.weeks ?? [];
    final chosen = requestedWeek == null
        ? weeks.indexWhere(
            (w) => oldNumber != null
                ? w.number == oldNumber
                : w.contains(DateTime.now()),
          )
        : weeks.indexWhere((week) => week.number == requestedWeek);
    _index = chosen < 0 ? 0 : chosen;
    final old = _pages;
    _pages = PageController(initialPage: _index);
    if (old != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealWeek(_index));
  }

  @override
  void dispose() {
    _pages?.dispose();
    _weekStrip.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= (_semester?.weeks.length ?? 0)) return;
    _pages!.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    _revealWeek(index);
  }

  void _revealWeek(int index) {
    if (!_weekStrip.hasClients) return;
    _weekStrip.animateTo(
      (index * 76.0 - 76).clamp(0, _weekStrip.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _today() {
    final semester = _semesters
        .where((s) => s.weeks.any((w) => w.contains(DateTime.now())))
        .firstOrNull;
    if (semester == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前日期不在已保存学期内')));
      return;
    }
    if (_term != semester.term) {
      setState(() {
        _term = semester.term;
        _index = -1;
        _reset();
      });
      return;
    }
    _go(semester.weeks.indexWhere((w) => w.contains(DateTime.now())));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.snapshot.timetable;
    final weeks = _semester?.weeks ?? [];
    final loading = widget.snapshot.status == FeatureLoadStatus.loading;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    weeks.elementAtOrNull(_index)?.name ?? '本地课表',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (widget.snapshot.error case final error?)
                IconButton(
                  tooltip: '加载提示',
                  icon: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('加载提示'),
                      content: Text('${error.message}\n已保存课表仍可离线查看。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                tooltip: '回到本周',
                onPressed: _today,
                icon: const Icon(Icons.today_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: '课表选项',
                icon: const Icon(Icons.tune),
                itemBuilder: (_) => [
                  if (data != null && data.terms.isNotEmpty)
                    const PopupMenuItem(value: 'term', child: Text('选择学期')),
                  if (!widget.offline)
                    PopupMenuItem(
                      value: 'update',
                      enabled: !loading,
                      child: const Text('本地化课表'),
                    ),
                  const PopupMenuItem(value: 'info', child: Text('课表信息')),
                ],
                onSelected: (action) async {
                  if (action == 'update') {
                    await widget.onQuery(
                      FeatureQuery(
                        view: FeatureQueryView.scheduleWeek,
                        term: _term,
                        updateSchedule: true,
                      ),
                    );
                  } else if (action == 'term') {
                    final term = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('选择学期'),
                        children: [
                          for (final entry in data!.terms.entries)
                            SimpleDialogOption(
                              onPressed: () =>
                                  Navigator.pop(context, entry.key),
                              child: Text(
                                '${entry.value}${entry.key == _term ? ' ✓' : ''}',
                              ),
                            ),
                        ],
                      ),
                    );
                    if (!mounted || term == null) return;
                    setState(() {
                      _term = term;
                      _index = 0;
                      final old = _pages;
                      _pages = PageController();
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => old?.dispose(),
                      );
                    });
                  } else {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('课表信息'),
                        content: Text(
                          '${data?.terms[_term] ?? '尚未选择学期'}\n本地课表 · 更新于 ${_semester?.updatedAt ?? '尚未导入'}\n首次自动导入后从本地读取。左右滑动切换周次；点击“本地化课表”可联网更新并保存整学期课表。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        if (weeks.isNotEmpty)
          _WeekStrip(
            controller: _weekStrip,
            weeks: weeks,
            selectedIndex: _index,
            onSelected: _go,
          ),
        Expanded(
          child: weeks.isEmpty
              ? Center(
                  child: Text(
                    widget.offline ? '暂无已保存课表，请登录后本地化课表' : '暂无已保存课表，请点击本地化课表',
                  ),
                )
              : PageView.builder(
                  key: ValueKey(_pages),
                  controller: _pages,
                  itemCount: weeks.length,
                  onPageChanged: (index) {
                    setState(() => _index = index);
                    _revealWeek(index);
                  },
                  itemBuilder: (context, index) =>
                      _TimetableGrid(week: weeks[index]),
                ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.controller,
    required this.weeks,
    required this.selectedIndex,
    required this.onSelected,
  });

  final ScrollController controller;
  final List<TimetableWeek> weeks;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: ListView.separated(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: weeks.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final week = weeks[index];
        final selected = index == selectedIndex;
        return Material(
          key: ValueKey('week-thumbnail-${week.number}'),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(index),
            child: SizedBox(
              width: 68,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      week.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 7,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                        children: [
                          for (var slot = 0; slot < 28; slot++)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hasCourse(week, slot)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.primary
                                          .withValues(alpha: .18),
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
      },
    ),
  );

  bool _hasCourse(TimetableWeek week, int slot) {
    final day = slot % 7 + 1;
    final period = slot ~/ 7;
    return week.courses.any((course) {
      if (course.day != day || course.begin == null) return false;
      return ((course.begin! - 1) * 4 ~/ 13).clamp(0, 3) == period;
    });
  }
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({required this.week});
  final TimetableWeek week;
  void _details(BuildContext context, TimetableCourse course) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.detail.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (course.detail.subtitle != null)
                    Text(course.detail.subtitle!),
                  for (final field in course.detail.fields)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('${field.label}：${field.value}'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final sections = [...week.sections]
      ..sort((a, b) => a.number.compareTo(b.number));
    bool placed(TimetableCourse course) =>
        course.day != null &&
        course.day! >= 1 &&
        course.day! <= 7 &&
        sections.any((s) => s.number == course.begin) &&
        sections.any((s) => s.number == (course.end ?? course.begin)) &&
        (course.end ?? course.begin!) >= course.begin!;
    final unknown = week.courses.where((course) => !placed(course));
    const rowHeight = 76.0;
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 42),
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '周${'一二三四五六日'[day - 1]}\n${week.start == null ? '' : '${week.start!.add(Duration(days: day - 1)).month}/${week.start!.add(Duration(days: day - 1)).day}'}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: sections.length * rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 42,
                  child: Column(
                    children: [
                      for (final section in sections)
                        SizedBox(
                          height: rowHeight,
                          child: Center(
                            child: Text(
                              '${section.number}\n${section.start}\n${section.end}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var day = 1; day <= 7; day++)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final courses =
                            week.courses
                                .where((c) => placed(c) && c.day == day)
                                .toList()
                              ..sort((a, b) => a.begin!.compareTo(b.begin!));
                        final groups = <List<TimetableCourse>>[];
                        var groupEnd = -1;
                        for (final course in courses) {
                          final end = course.end ?? course.begin!;
                          if (groups.isEmpty || course.begin! > groupEnd) {
                            groups.add([]);
                            groupEnd = end;
                          } else if (end > groupEnd) {
                            groupEnd = end;
                          }
                          groups.last.add(course);
                        }
                        return Stack(
                          children: [
                            for (var row = 0; row < sections.length; row++)
                              Positioned(
                                top: row * rowHeight,
                                left: 0,
                                right: 0,
                                height: rowHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: .2),
                                    ),
                                  ),
                                ),
                              ),
                            for (final group in groups)
                              for (var i = 0; i < group.length; i++)
                                ..._course(
                                  context,
                                  group,
                                  i,
                                  sections,
                                  constraints.maxWidth,
                                  rowHeight,
                                ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          for (final course in unknown)
            ListTile(
              title: Text(course.detail.title),
              subtitle: const Text('时间或节次未完整提供'),
              onTap: () => _details(context, course),
            ),
          if (week.courses.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('本周暂无课程')),
        ],
      ),
    );
  }

  List<Widget> _course(
    BuildContext context,
    List<TimetableCourse> courses,
    int i,
    List<TimetableSection> sections,
    double width,
    double height,
  ) {
    final course = courses[i];
    // ponytail: fixed columns per overlap group; reuse lanes if density grows.
    final lanes = courses.length;
    final start = sections.indexWhere((s) => s.number == course.begin);
    final end = sections.indexWhere(
      (s) => s.number == (course.end ?? course.begin),
    );
    return [
      Positioned(
        top: start * height + 1,
        height: (end - start + 1) * height - 2,
        left: i * width / lanes + 1,
        width: (width / lanes - 2).clamp(0, width),
        child: Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _details(context, course),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                '${course.detail.title}\n${course.place ?? ''}',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.fade,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
