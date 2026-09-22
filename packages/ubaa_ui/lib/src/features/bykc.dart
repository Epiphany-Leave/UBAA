part of '../widgets.dart';

class _BykcView extends StatefulWidget {
  const _BykcView({
    required this.snapshot,
    required this.page,
    required this.onPageChanged,
    required this.onQuery,
    this.initialQuery,
    this.onWrite,
    this.onSignWrite,
    this.calendar,
  });

  final FeatureSnapshot snapshot;
  final _FeatureSubpage? page;
  final ValueChanged<_FeatureSubpage?> onPageChanged;
  final FeatureQuery? initialQuery;
  final Future<void> Function(FeatureQuery) onQuery;
  final Future<void> Function(WriteOperation operation, int courseId)? onWrite;
  final BykcSignStarter? onSignWrite;
  final BoyaCalendarActions? calendar;

  @override
  State<_BykcView> createState() => _BykcViewState();
}

class _BykcViewState extends State<_BykcView> {
  FeatureQueryView _view = FeatureQueryView.summary;
  List<FeatureDetail> _courses = const [];
  FeatureDetail? _selectedCourse;
  FeatureDetail? _courseDetail;
  List<FeatureDetail> _chosen = const [];
  List<FeatureDetail> _statistics = const [];
  FeaturePagination? _pagination;
  String? _statisticsSummary;
  String? _status;

  @override
  void initState() {
    super.initState();
    _view = widget.initialQuery?.view ?? FeatureQueryView.summary;
    if (_view == FeatureQueryView.summary) {
      _courses = widget.snapshot.details;
      _pagination = widget.snapshot.pagination;
    }
    if (_view == FeatureQueryView.bykcChosenCourses &&
        widget.snapshot.status == FeatureLoadStatus.success) {
      _chosen = widget.snapshot.details;
    }
  }

  @override
  void didUpdateWidget(covariant _BykcView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.status
        case FeatureLoadStatus.success ||
            FeatureLoadStatus.empty ||
            FeatureLoadStatus.stale) {
      switch (_view) {
        case FeatureQueryView.summary:
          _courses = widget.snapshot.details;
          _pagination = widget.snapshot.pagination;
        case FeatureQueryView.bykcChosenCourses:
          _chosen = widget.snapshot.details;
        case FeatureQueryView.bykcDetail:
          _courseDetail = widget.snapshot.details.firstOrNull;
        case FeatureQueryView.bykcStatistics:
          _statistics = widget.snapshot.details;
          _statisticsSummary = widget.snapshot.summary;
        default:
          break;
      }
    }
  }

  Future<void> _open(_FeatureSubpage page, FeatureQueryView view) async {
    widget.onPageChanged(page);
    await _query(
      FeatureQuery(view: view, page: view == FeatureQueryView.summary ? 1 : 0),
    );
  }

  Future<void> _query(FeatureQuery query) async {
    setState(() => _view = query.view);
    await widget.onQuery(query);
  }

  @override
  Widget build(BuildContext context) => switch (widget.page) {
    _FeatureSubpage.bykcCourses => _courseList(context),
    _FeatureSubpage.bykcCourseDetail => _courseDetailView(context),
    _FeatureSubpage.bykcChosen => _chosenList(context),
    _FeatureSubpage.bykcStatistics => _statisticsView(context),
    _ => _home(context),
  };

  Widget _home(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    padding: const EdgeInsets.all(16),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 1.05,
    children: [
      _LibbookHomeCard(
        title: '选择课程',
        description: '浏览可选博雅课程',
        icon: Icons.format_list_bulleted,
        onTap: () =>
            _open(_FeatureSubpage.bykcCourses, FeatureQueryView.summary),
      ),
      _LibbookHomeCard(
        title: '我的课程',
        description: '查看已选、签到签退',
        icon: Icons.menu_book_outlined,
        onTap: () => _open(
          _FeatureSubpage.bykcChosen,
          FeatureQueryView.bykcChosenCourses,
        ),
      ),
      _LibbookHomeCard(
        title: '课程统计',
        description: '查看学时统计',
        icon: Icons.bar_chart,
        onTap: () => _open(
          _FeatureSubpage.bykcStatistics,
          FeatureQueryView.bykcStatistics,
        ),
      ),
    ],
  );

  Widget _courseList(BuildContext context) {
    final courses = _status == null
        ? _courses
        : _courses
              .where((course) => _academicField(course, '状态') == _status)
              .toList(growable: false);
    return RefreshIndicator(
      onRefresh: () => _query(
        FeatureQuery(
          view: FeatureQueryView.summary,
          page: _pagination?.page ?? 1,
        ),
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _BykcStickyHeader(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _status == null
                              ? context.tr('全部课程')
                              : context.tr("状态：{0}", [
                                  context.tr(_statusLabel(_status!)),
                                ]),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      PopupMenuButton<String?>(
                        tooltip: context.tr('筛选课程'),
                        icon: const Icon(Icons.tune),
                        initialValue: _status,
                        onSelected: (value) => setState(() => _status = value),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: null,
                            child: Text(context.tr('全部课程')),
                          ),
                          PopupMenuItem(
                            value: 'available',
                            child: Text(context.tr('可选')),
                          ),
                          PopupMenuItem(
                            value: 'preview',
                            child: Text(context.tr('预告')),
                          ),
                          PopupMenuItem(
                            value: 'selected',
                            child: Text(context.tr('已选')),
                          ),
                          PopupMenuItem(
                            value: 'full',
                            child: Text(context.tr('已满')),
                          ),
                          PopupMenuItem(
                            value: 'ended',
                            child: Text(context.tr('已结束')),
                          ),
                          PopupMenuItem(
                            value: 'expired',
                            child: Text(context.tr('已过期')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.snapshot.status == FeatureLoadStatus.loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (courses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _stateMessage('暂无符合条件的博雅课程'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverList.builder(
                itemCount: courses.length,
                itemBuilder: (context, index) => _BykcCourseCard(
                  detail: courses[index],
                  onTap: () => _openCourse(courses[index]),
                ),
              ),
            ),
          if (_pagination case final pagination?)
            SliverToBoxAdapter(child: _serverPager(pagination)),
        ],
      ),
    );
  }

  Widget _chosenList(BuildContext context) => RefreshIndicator(
    onRefresh: () =>
        _query(const FeatureQuery(view: FeatureQueryView.bykcChosenCourses)),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.snapshot.status == FeatureLoadStatus.loading)
          const LinearProgressIndicator(),
        if (_chosen.isEmpty)
          SizedBox(height: 500, child: _stateMessage('暂无已选博雅课程'))
        else
          for (final course in _chosen)
            _BykcChosenCard(
              detail: course,
              calendar: widget.calendar,
              onWrite: widget.onWrite,
              onSignWrite: widget.onSignWrite,
            ),
      ],
    ),
  );

  Future<void> _openCourse(FeatureDetail course) async {
    final courseId =
        course.action<BykcSelectAction>()?.courseId ??
        int.tryParse(_academicField(course, '课程 ID') ?? '');
    if (courseId == null) return;
    setState(() {
      _selectedCourse = course;
      _courseDetail = null;
    });
    widget.onPageChanged(_FeatureSubpage.bykcCourseDetail);
    await _query(
      FeatureQuery(
        view: FeatureQueryView.bykcDetail,
        courseId: courseId.toString(),
      ),
    );
  }

  Widget _courseDetailView(BuildContext context) {
    final detail = _courseDetail;
    if (detail == null) {
      if (widget.snapshot.status == FeatureLoadStatus.failure) {
        return _stateMessage('课程详情加载失败');
      }
      return const Center(child: CircularProgressIndicator());
    }
    final detailSelect = detail.action<BykcSelectAction>();
    final detailDeselect = detail.action<BykcDeselectAction>();
    final select = detailSelect?.eligibility == ActionEligibility.unknown
        ? _selectedCourse?.action<BykcSelectAction>() ?? detailSelect
        : detailSelect;
    final deselect = detailDeselect?.eligibility == ActionEligibility.unknown
        ? _selectedCourse?.action<BykcDeselectAction>() ?? detailDeselect
        : detailDeselect;
    final selectedField = _academicField(detail, '已选');
    final selected =
        selectedField == '是' ||
        (selectedField == null &&
            _selectedCourse != null &&
            _academicField(_selectedCourse!, '状态') == 'selected');
    final action = selected ? deselect : select;
    final actionCourseId = switch (action) {
      BykcSelectAction(:final courseId) => courseId,
      BykcDeselectAction(:final courseId) => courseId,
      _ => null,
    };
    final enabled =
        action?.eligibility == ActionEligibility.allowed &&
        actionCourseId != null &&
        widget.onWrite != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    selected
                        ? context.tr('已选')
                        : context.tr(
                            _statusLabel(_academicField(detail, '状态') ?? '未知'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _BykcDetailSection(
          title: '基本信息',
          fields: [
            if (detail.subtitle case final teacher? when teacher.isNotEmpty)
              ('授课教师', teacher),
            if (_academicField(detail, '地点') case final location?)
              ('上课地点', location),
            if (_academicField(detail, '开课单位') case final college?)
              ('开课单位', college),
            if (_academicField(detail, '课程分类') case final category?)
              ('课程分类', category),
            if (_academicField(detail, '已选人数') case final count?)
              ('报名人数', '$count / ${_academicField(detail, '容量') ?? '-'}'),
          ],
        ),
        if (_hasAnyField(detail, const ['适用校区', '适用学院', '适用年级', '适用人群'])) ...[
          const SizedBox(height: 12),
          _BykcDetailSection(
            title: '适用范围',
            fields: [
              if (_academicField(detail, '适用校区') case final value?)
                ('校区', value),
              if (_academicField(detail, '适用学院') case final value?)
                ('学院', value),
              if (_academicField(detail, '适用年级') case final value?)
                ('年级', value),
              if (_academicField(detail, '适用人群') case final value?)
                ('人群', value),
            ],
          ),
        ],
        if (_hasAnyField(detail, const ['联系人', '联系电话'])) ...[
          const SizedBox(height: 12),
          _BykcDetailSection(
            title: '联系方式',
            fields: [
              if (_academicField(detail, '联系人') case final value?)
                ('联系人', value),
              if (_academicField(detail, '联系电话') case final value?)
                ('联系电话', value),
            ],
          ),
        ],
        if (_academicField(detail, '课程简介') case final description?) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('课程简介'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _BykcDetailSection(
          title: '时间安排',
          fields: [
            if (_academicField(detail, '开始') case final start?)
              ('上课时间', '$start 至 ${_academicField(detail, '结束') ?? '-'}'),
            if (_academicField(detail, '选课开始') case final start?)
              ('选课时间', '$start 至 ${_academicField(detail, '选课截止') ?? '-'}'),
            if (_academicField(detail, '退选截止') case final end?) ('退选截止', end),
          ],
        ),
        const SizedBox(height: 20),
        if (widget.calendar case final calendar?)
          BoyaCalendarCard(
            key: ValueKey(_academicField(detail, '课程 ID')),
            course: detail,
            actions: calendar,
            selected: selected,
            preview: _academicField(detail, '状态') == 'preview',
          ),
        FilledButton.icon(
          onPressed: !enabled
              ? null
              : () => widget.onWrite!(action!.operation, actionCourseId),
          icon: Icon(
            selected ? Icons.remove_circle_outline : Icons.add_circle_outline,
          ),
          label: Text(
            enabled
                ? selected
                      ? context.tr('准备退选')
                      : context.tr('准备选课')
                : selected
                ? context.tr('当前不可退选')
                : context.tr('当前不可选课'),
          ),
        ),
        if (!enabled) ...[
          const SizedBox(height: 8),
          Text(
            action == null
                ? context.tr('课程未返回可执行的选课信息，请刷新后重试。')
                : context.tr('当前不在操作时间、课程已满，或选课资格尚未确认。'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  bool _hasAnyField(FeatureDetail detail, List<String> labels) =>
      labels.any((label) => _academicField(detail, label) != null);

  Widget _statisticsView(BuildContext context) {
    final total =
        RegExp(r'\d+').firstMatch(_statisticsSummary ?? '')?.group(0) ?? '-';
    return RefreshIndicator(
      onRefresh: () =>
          _query(const FeatureQuery(view: FeatureQueryView.bykcStatistics)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(context.tr('总体净有效次数')),
                  const SizedBox(height: 4),
                  Text(total, style: Theme.of(context).textTheme.displaySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.snapshot.status == FeatureLoadStatus.loading)
            const LinearProgressIndicator(),
          if (_statistics.isEmpty)
            SizedBox(height: 360, child: _stateMessage('暂无博雅课程统计'))
          else ...[
            const _BykcStatisticsHeader(),
            for (final item in _statistics) ...[
              _BykcStatisticsRow(detail: item),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stateMessage(String emptyText) {
    if (widget.snapshot.status == FeatureLoadStatus.failure) {
      return FriendlyErrorCard(
        error: widget.snapshot.error!,
        onRetry: () => _query(FeatureQuery(view: _view)),
      );
    }
    return Center(child: Text(context.tr(emptyText)));
  }

  Widget _serverPager(FeaturePagination pagination) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: context.tr('上一页'),
        onPressed: pagination.page <= 1
            ? null
            : () => _query(
                FeatureQuery(
                  view: FeatureQueryView.summary,
                  page: pagination.page - 1,
                ),
              ),
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        context.tr("第 {0} / {1} 页", [
          pagination.page,
          pagination.effectiveTotalPages,
        ]),
      ),
      IconButton(
        tooltip: context.tr('下一页'),
        onPressed:
            !(pagination.hasMore ??
                pagination.page < pagination.effectiveTotalPages)
            ? null
            : () => _query(
                FeatureQuery(
                  view: FeatureQueryView.summary,
                  page: pagination.page + 1,
                ),
              ),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

String _statusLabel(String status) => switch (status) {
  'available' => '可选',
  'preview' => '预告',
  'selected' => '已选',
  'full' => '已满',
  'ended' => '已结束',
  'expired' => '已过期',
  _ => status,
};

extension _BykcQueryControls on _FeatureQueryControlsState {
  List<Widget> _bykcQueryFields(StateSetter setState) => <Widget>[
    if (widget.feature == FeatureId.bykc) ...<Widget>[
      DropdownButton<FeatureQueryView>(
        value: _bykcView,
        onChanged: _submitting
            ? null
            : (value) =>
                  setState(() => _bykcView = value ?? FeatureQueryView.summary),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('课程列表')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.bykcDetail,
            child: Text(context.tr('课程详情')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.bykcChosenCourses,
            child: Text(context.tr('已选课程')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.bykcStatistics,
            child: Text(context.tr('修读统计')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.bykcProfile,
            child: Text(context.tr('个人资料')),
          ),
        ],
      ),
      if (_bykcView == FeatureQueryView.summary) ...<Widget>[
        SizedBox(
          width: 110,
          child: TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('页码'),
              hintText: context.tr('从 1 开始'),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _sizeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('每页数量'),
              hintText: '1–100',
              isDense: true,
            ),
          ),
        ),
      ],
      if (_bykcView == FeatureQueryView.bykcDetail) ...<Widget>[
        SizedBox(
          width: 150,
          child: TextField(
            controller: _bykcCourseController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('课程 ID'),
              hintText: context.tr('从课程列表选择'),
              isDense: true,
            ),
          ),
        ),
        _valuePicker(
          label: '从当前列表选择课程',
          values: _detailFieldValues('课程 ID'),
          onSelected: (value) => _bykcCourseController.text = value,
        ),
      ],
    ],
  ];
}

extension _BykcDetailActions on _FeatureDetailListState {
  List<Widget> _bykcCourseWriteFields(
    BuildContext context,
    int? courseId,
    BykcSelectAction? bykcSelectAction,
    BykcDeselectAction? bykcDeselectAction,
    bool canBykcSelect,
    bool canBykcDeselect,
  ) => <Widget>[
    if (widget.feature == FeatureId.bykc &&
        widget.onBykcWrite != null &&
        (bykcSelectAction != null ||
            bykcDeselectAction != null ||
            courseId != null)) ...<Widget>[
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: canBykcSelect
                ? () => widget.onBykcWrite!(
                    WriteOperation.bykcSelectCourse,
                    bykcSelectAction!.courseId,
                  )
                : null,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(context.tr('准备选课')),
          ),
          if (bykcDeselectAction != null || courseId != null)
            OutlinedButton.icon(
              onPressed: canBykcDeselect
                  ? () => widget.onBykcWrite!(
                      bykcDeselectAction!.operation,
                      bykcDeselectAction.courseId,
                    )
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(context.tr('准备退选')),
            ),
        ],
      ),
      if (!canBykcSelect || !canBykcDeselect)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            context.tr('当前课程状态不支持该操作；最终资格和时间窗仍由 Core 校验。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  ];

  List<Widget> _bykcSignWriteFields(
    BuildContext context,
    BykcSignAction? bykcSignInAction,
    BykcSignAction? bykcSignOutAction,
    bool canBykcSign,
    bool canBykcSignOut,
  ) => <Widget>[
    if (widget.feature == FeatureId.bykc &&
        widget.onBykcSignWrite != null &&
        (bykcSignInAction != null || bykcSignOutAction != null)) ...<Widget>[
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          if (bykcSignInAction != null)
            OutlinedButton.icon(
              onPressed: canBykcSign
                  ? () => widget.onBykcSignWrite!(bykcSignInAction)
                  : null,
              icon: const Icon(Icons.login),
              label: Text(context.tr('准备博雅签到')),
            ),
          if (bykcSignOutAction != null)
            OutlinedButton.icon(
              onPressed: canBykcSignOut
                  ? () => widget.onBykcSignWrite!(bykcSignOutAction)
                  : null,
              icon: const Icon(Icons.logout),
              label: Text(context.tr('准备博雅签退')),
            ),
        ],
      ),
      if ((bykcSignInAction != null && !canBykcSign) ||
          (bykcSignOutAction != null && !canBykcSignOut))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            context.tr('当前不在可操作时间窗或状态不允许，具体条件由 Core 判定。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  ];

  int? _courseId(FeatureDetail detail) {
    for (final field in detail.fields) {
      if (field.label == '课程 ID') return int.tryParse(field.value.trim());
    }
    return null;
  }

  BykcSignAction? _bykcSignAction(FeatureDetail detail, BykcSignKind kind) {
    for (final action in detail.actions) {
      if (action is BykcSignAction && action.kind == kind) return action;
    }
    return null;
  }
}
