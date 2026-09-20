part of '../widgets.dart';

class _CgyyView extends StatefulWidget {
  const _CgyyView({
    required this.snapshot,
    required this.page,
    required this.onPageChanged,
    required this.onQuery,
    this.initialQuery,
    this.onReserve,
    this.onCancel,
  });
  final FeatureSnapshot snapshot;
  final _FeatureSubpage? page;
  final ValueChanged<_FeatureSubpage?> onPageChanged;
  final Future<void> Function(FeatureQuery) onQuery;
  final FeatureQuery? initialQuery;
  final CgyyReservationStarter? onReserve;
  final CgyyCancelStarter? onCancel;
  @override
  State<_CgyyView> createState() => _CgyyViewState();
}

class _CgyyViewState extends State<_CgyyView> {
  FeatureQuery _query = const FeatureQuery();
  List<FeatureDetail> _sites = [],
      _purposes = [],
      _slots = [],
      _orders = [],
      _lock = [];
  FeatureDetail? _order;
  int? _site;
  String _campus = '全部', _search = '';
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final List<CgyyReserveAction> _selected = [];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? const FeatureQuery();
    if (_query.view == FeatureQueryView.summary)
      _sites = widget.snapshot.details;
    if (widget.page == _FeatureSubpage.cgyyReserve) {
      _queue(const FeatureQuery());
    } else if (widget.page == _FeatureSubpage.cgyyOrders) {
      _queue(const FeatureQuery(view: FeatureQueryView.cgyyOrders, page: 1));
    } else if (widget.page == _FeatureSubpage.cgyyOrderDetail) {
      _queue(_query);
    }
  }

  @override
  void didUpdateWidget(covariant _CgyyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.snapshot, widget.snapshot) ||
        !(widget.snapshot.status == FeatureLoadStatus.success ||
            widget.snapshot.status == FeatureLoadStatus.empty))
      return;
    final details = widget.snapshot.details;
    switch (_query.view) {
      case FeatureQueryView.summary:
        _sites = details;
        if (widget.page == _FeatureSubpage.cgyyReserve) {
          _queue(const FeatureQuery(view: FeatureQueryView.cgyyPurposeTypes));
        }
      case FeatureQueryView.cgyyPurposeTypes:
        _purposes = details;
        if (_sites.isNotEmpty) _selectSite(_sites.first, queued: true);
      case FeatureQueryView.cgyyDayInfo:
        _slots = details;
      case FeatureQueryView.cgyyOrders:
        _orders = details;
      case FeatureQueryView.cgyyOrderDetail:
        _order = details.firstOrNull;
      case FeatureQueryView.cgyyLockCode:
        _lock = details;
      default:
        break;
    }
  }

  Future<void> _load(FeatureQuery query) async {
    setState(() => _query = query);
    await widget.onQuery(query);
  }

  void _queue(FeatureQuery query) {
    _query = query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onQuery(query);
    });
  }

  void _selectSite(FeatureDetail site, {bool queued = false}) {
    final id = int.tryParse(_academicField(site, '站点 ID') ?? '');
    if (id == null) return;
    _site = id;
    _selected.clear();
    _slots = [];
    final query = FeatureQuery(
      view: FeatureQueryView.cgyyDayInfo,
      siteId: id,
      date: _date,
    );
    if (queued) {
      _queue(query);
    } else {
      _load(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.page == null)
      return GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          _LibbookHomeCard(
            title: '预约研讨室',
            description: '选择校区、楼栋和时段',
            icon: Icons.date_range,
            onTap: () {
              widget.onPageChanged(_FeatureSubpage.cgyyReserve);
              _load(const FeatureQuery());
            },
          ),
          _LibbookHomeCard(
            title: '我的预约',
            description: '查看状态、详情与取消预约',
            icon: Icons.history,
            onTap: () {
              widget.onPageChanged(_FeatureSubpage.cgyyOrders);
              _load(
                const FeatureQuery(view: FeatureQueryView.cgyyOrders, page: 1),
              );
            },
          ),
          _LibbookHomeCard(
            title: '查看密码',
            description: '查看当前预约的门锁密码',
            icon: Icons.lock,
            onTap: () {
              widget.onPageChanged(_FeatureSubpage.cgyyLockCode);
              _load(const FeatureQuery(view: FeatureQueryView.cgyyLockCode));
            },
          ),
        ],
      );
    return Column(
      children: [
        if (widget.snapshot.status == FeatureLoadStatus.loading)
          const LinearProgressIndicator(),
        if (widget.snapshot.status == FeatureLoadStatus.failure)
          TextButton.icon(
            onPressed: () => _load(_query),
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('加载失败，点击重试')),
          ),
        Expanded(
          child: switch (widget.page) {
            _FeatureSubpage.cgyyReserve => _reserve(),
            _FeatureSubpage.cgyyOrders => _orderList(),
            _FeatureSubpage.cgyyOrderDetail => _orderDetail(),
            _ => RefreshIndicator(
              onRefresh: () => _load(
                const FeatureQuery(view: FeatureQueryView.cgyyLockCode),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final detail in _lock)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            for (final field in detail.fields)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SelectableText(
                                  '${context.tr(field.label)}：${field.value}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_lock.isEmpty)
                    Center(child: Text(context.tr('暂无可用门锁密码'))),
                ],
              ),
            ),
          },
        ),
      ],
    );
  }

  Widget _reserve() {
    final campuses = {
      '全部',
      ..._sites.map((s) => _academicField(s, '校区')).whereType<String>(),
    };
    final sites = _sites
        .where((s) => _campus == '全部' || _academicField(s, '校区') == _campus)
        .toList();
    final grouped = <String, List<FeatureDetail>>{};
    for (final slot in _slots) {
      final name = _academicField(slot, '研讨室') ?? slot.title;
      if (_search.isEmpty ||
          name.toLowerCase().contains(_search.toLowerCase())) {
        grouped.putIfAbsent(name, () => []).add(slot);
      }
    }
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final campus in campuses)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(context.tr(campus)),
                    selected: _campus == campus,
                    onSelected: (_) {
                      setState(() => _campus = campus);
                      final next = _sites
                          .where(
                            (s) =>
                                campus == '全部' ||
                                _academicField(s, '校区') == campus,
                          )
                          .firstOrNull;
                      if (next != null) _selectSite(next);
                    },
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_libbookDate(_date)),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateUtils.dateOnly(DateTime.now()),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null || !mounted) return;
                  setState(() {
                    _date = date;
                    _selected.clear();
                    _slots = [];
                  });
                  if (_site != null)
                    _load(
                      FeatureQuery(
                        view: FeatureQueryView.cgyyDayInfo,
                        siteId: _site,
                        date: date,
                      ),
                    );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.tr('搜索研讨室'),
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final site in sites)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text('${site.subtitle ?? ''} ${site.title}'.trim()),
                    selected: '${_site ?? ''}' == _academicField(site, '站点 ID'),
                    onSelected: (_) => _selectSite(site),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Text(context.tr('选择同一研讨室的一个或两个相邻时段')),
        ),
        Expanded(child: _reservationTable(grouped)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected.isEmpty || widget.onReserve == null
                  ? null
                  : _form,
              child: Text(
                _selected.isEmpty
                    ? context.tr('请选择可预约时段')
                    : context.tr("下一步（已选 {0} 个时段）", [_selected.length]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reservationTable(Map<String, List<FeatureDetail>> grouped) {
    if (grouped.isEmpty) return Center(child: Text(context.tr('暂无符合条件的研讨室时段')));
    final times = <String, String>{};
    String key(FeatureDetail slot) =>
        _academicField(slot, '时段 ID') ??
        _academicField(slot, '时段') ??
        slot.title;
    for (final slots in grouped.values) {
      for (final slot in slots) {
        times[key(slot)] = _academicField(slot, '时段') ?? slot.title;
      }
    }
    Widget cell(Widget child, {double width = 100}) => Container(
      width: width,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: .5,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 100 + times.length * 100.0,
        child: Column(
          children: [
            Row(
              children: [
                cell(Text(context.tr('研讨室'))),
                for (final time in times.values)
                  cell(Text(time, textAlign: TextAlign.center)),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in grouped.entries)
                    Row(
                      children: [
                        cell(Text(entry.key)),
                        for (final time in times.keys)
                          cell(switch (entry.value
                              .where((slot) => key(slot) == time)
                              .firstOrNull) {
                            final slot? => _slotCell(slot),
                            _ => const SizedBox.expand(),
                          }),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotCell(FeatureDetail detail) {
    final action = detail.action<CgyyReserveAction>();
    final allowed =
        action != null && action.eligibility == ActionEligibility.allowed;
    final selected =
        action != null &&
        _selected.any(
          (a) => a.spaceId == action.spaceId && a.timeId == action.timeId,
        );
    return Semantics(
      label: context.tr("{0} {1}", [
        detail.title,
        context.tr(allowed ? '可预约' : '不可预约'),
      ]),
      selected: selected,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : allowed
            ? const Color(0xff98fb98)
            : Colors.transparent,
        child: InkWell(
          onTap: !allowed
              ? null
              : () => setState(() {
                  if (selected) {
                    _selected.removeWhere(
                      (a) =>
                          a.spaceId == action.spaceId &&
                          a.timeId == action.timeId,
                    );
                  } else {
                    if (_selected.length != 1 ||
                        _selected.first.spaceId != action.spaceId ||
                        (_selected.first.timeOrdinal - action.timeOrdinal)
                                .abs() !=
                            1)
                      _selected.clear();
                    _selected.add(action);
                    _selected.sort(
                      (a, b) => a.timeOrdinal.compareTo(b.timeOrdinal),
                    );
                  }
                }),
          child: SizedBox.expand(
            child: Center(
              child: Text(
                selected ? context.tr('已选') : '',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _form() async {
    final selected = List<CgyyReserveAction>.of(_selected);
    final fields = <String, TextEditingController>{
      for (final label in ['联系电话', '预约主题', '参与人数', '活动内容', '参与人说明'])
        label: TextEditingController(text: label == '参与人数' ? '1' : ''),
    };
    int? purpose = int.tryParse(
      _purposes.firstOrNull == null
          ? ''
          : _academicField(_purposes.first, '用途编号') ?? '',
    );
    bool philosophy = false, outside = false;
    String? error;
    final input = await showDialog<CgyySubmitInput>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(context.tr('填写研讨室预约信息')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr("{0} · 已选 {1} 个时段", [
                      _libbookDate(_date),
                      selected.length,
                    ]),
                  ),
                  for (final entry in fields.entries)
                    TextField(
                      controller: entry.value,
                      keyboardType: entry.key == '参与人数'
                          ? TextInputType.number
                          : entry.key == '联系电话'
                          ? TextInputType.phone
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: context.tr(entry.key),
                      ),
                    ),
                  DropdownButtonFormField<int>(
                    initialValue: purpose,
                    decoration: InputDecoration(labelText: context.tr('活动类型')),
                    items: [
                      for (final item in _purposes)
                        if (int.tryParse(_academicField(item, '用途编号') ?? '')
                            case final int id)
                          DropdownMenuItem(value: id, child: Text(item.title)),
                    ],
                    onChanged: (value) => update(() => purpose = value),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('哲学社会科学类活动')),
                    value: philosophy,
                    onChanged: (value) =>
                        update(() => philosophy = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('含校外参与人')),
                    value: outside,
                    onChanged: (value) =>
                        update(() => outside = value ?? false),
                  ),
                  if (error != null)
                    Text(
                      context.tr(error!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('取消')),
            ),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(fields['参与人数']!.text);
                if (fields.values.any((c) => c.text.trim().isEmpty) ||
                    purpose == null ||
                    count == null ||
                    count <= 0) {
                  update(() => error = '请完整填写预约信息并选择活动类型');
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  CgyySubmitInput(
                    actions: selected,
                    phone: fields['联系电话']!.text.trim(),
                    theme: fields['预约主题']!.text.trim(),
                    purposeType: purpose!,
                    joinerNum: count,
                    activityContent: fields['活动内容']!.text.trim(),
                    joiners: fields['参与人说明']!.text.trim(),
                    isPhilosophySocialSciences: philosophy,
                    isOffSchoolJoiner: outside,
                  ),
                );
              },
              child: Text(context.tr('准备预约')),
            ),
          ],
        ),
      ),
    );
    // 对话框退出动画期间 TextField 仍持有 controller。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in fields.values) {
      controller.dispose();
    }
    if (input != null && mounted) await widget.onReserve!(input);
  }

  Widget _orderList() => RefreshIndicator(
    onRefresh: () =>
        _load(const FeatureQuery(view: FeatureQueryView.cgyyOrders, page: 1)),
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_orders.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(context.tr('暂无预约记录')),
          ),
        for (final order in _orders)
          Card(
            child: ListTile(
              title: Text(order.title),
              subtitle: Text(
                [
                  order.subtitle,
                  _academicField(order, '日期'),
                  _academicField(order, '订单状态说明'),
                ].whereType<String>().join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _order = order;
                widget.onPageChanged(_FeatureSubpage.cgyyOrderDetail);
                _load(
                  FeatureQuery(
                    view: FeatureQueryView.cgyyOrderDetail,
                    orderId: int.tryParse(_academicField(order, '订单编号') ?? ''),
                  ),
                );
              },
            ),
          ),
        if (widget.snapshot.pagination case final pagination?
            when pagination.hasMore == true ||
                _query.page < pagination.effectiveTotalPages)
          TextButton(
            onPressed: () => _load(
              FeatureQuery(
                view: FeatureQueryView.cgyyOrders,
                page: _query.page + 1,
              ),
            ),
            child: Text(context.tr('下一页')),
          ),
      ],
    ),
  );

  Widget _orderDetail() {
    final order = _order;
    if (order == null) return Center(child: Text(context.tr('暂无预约详情')));
    final cancel = order.action<CgyyCancelAction>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(order.title, style: Theme.of(context).textTheme.titleLarge),
        if (order.subtitle != null) Text(order.subtitle!),
        for (final field in order.fields)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('${context.tr(field.label)}：${field.value}'),
          ),
        if (cancel?.hasCanonicalTarget == true && widget.onCancel != null)
          OutlinedButton(
            onPressed: () => widget.onCancel!(cancel!),
            child: Text(context.tr('取消预约')),
          ),
      ],
    );
  }
}
