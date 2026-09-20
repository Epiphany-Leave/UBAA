part of '../widgets.dart';

class _LibbookView extends StatefulWidget {
  const _LibbookView({
    required this.snapshot,
    required this.onQuery,
    required this.page,
    required this.onPageChanged,
    this.initialQuery,
    this.onReserve,
    this.onCancel,
  });

  final FeatureSnapshot snapshot;
  final _FeatureSubpage? page;
  final ValueChanged<_FeatureSubpage?> onPageChanged;
  final FeatureQuery? initialQuery;
  final Future<void> Function(FeatureQuery) onQuery;
  final LibbookReserveStarter? onReserve;
  final LibbookCancelStarter? onCancel;

  @override
  State<_LibbookView> createState() => _LibbookViewState();
}

class _LibbookViewState extends State<_LibbookView> {
  FeatureQueryView _view = FeatureQueryView.summary;
  List<FeatureDetail> _libraries = [];
  List<FeatureDetail> _areas = [];
  List<FeatureDetail> _areaDetails = [];
  List<FeatureDetail> _seats = [];
  List<FeatureDetail> _bookings = [];
  String? _libraryId;
  String? _storeyId;
  String? _areaId;
  String? _areaName;
  String? _day;
  String? _segment;
  LibbookReserveAction? _selectedSeat;

  @override
  void initState() {
    super.initState();
    _libraries =
        widget.initialQuery == null ||
            widget.initialQuery?.view == FeatureQueryView.summary
        ? widget.snapshot.details
        : [];
  }

  @override
  void didUpdateWidget(covariant _LibbookView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snapshot.status
        case FeatureLoadStatus.success ||
            FeatureLoadStatus.empty ||
            FeatureLoadStatus.stale) {
      final details = widget.snapshot.details;
      switch (_view) {
        case FeatureQueryView.summary:
          _libraries = details;
          if (widget.page == _FeatureSubpage.libbookReserve &&
              details.isNotEmpty) {
            _selectLibrary(details.first, rebuild: false);
          }
        case FeatureQueryView.libbookAreas:
          _areas = details;
          if (details.isNotEmpty) _selectArea(details.first, rebuild: false);
        case FeatureQueryView.libbookAreaDetail:
          _areaDetails = details;
          final detail = details.firstOrNull;
          if (detail != null) {
            _day =
                _splitField(_academicField(detail, '可用日期')).firstOrNull ??
                _libbookDate(DateTime.now());
            final slot = _slots(detail).firstOrNull;
            if (slot != null) _selectSlot(slot, rebuild: false);
          }
        case FeatureQueryView.libbookSeats:
          _seats = details;
        case FeatureQueryView.libbookBookings:
          _bookings = details;
        default:
          break;
      }
    }
  }

  Future<void> _query(FeatureQuery query) async {
    setState(() => _view = query.view);
    await widget.onQuery(query);
  }

  void _queueQuery(FeatureQuery query) {
    _view = query.view;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) => switch (widget.page) {
    _FeatureSubpage.libbookReserve => _reserve(context),
    _FeatureSubpage.libbookBookings => _bookingList(context),
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
        title: '预约座位',
        description: '选择楼馆、分区和座位',
        icon: Icons.event_seat,
        onTap: () {
          widget.onPageChanged(_FeatureSubpage.libbookReserve);
          if (_libraries.isEmpty) {
            _query(const FeatureQuery());
          } else {
            _selectLibrary(_libraries.first);
          }
        },
      ),
      _LibbookHomeCard(
        title: '我的预约',
        description: '查看座位预约与取消',
        icon: Icons.history,
        onTap: () async {
          widget.onPageChanged(_FeatureSubpage.libbookBookings);
          await _query(
            const FeatureQuery(view: FeatureQueryView.libbookBookings, page: 1),
          );
        },
      ),
    ],
  );

  Widget _reserve(BuildContext context) {
    final selectedLibrary = _libraries
        .where((item) => _academicField(item, '馆 ID') == _libraryId)
        .firstOrNull;
    final storeys = selectedLibrary == null
        ? const <_LibbookStorey>[]
        : _storeys(selectedLibrary);
    final availableSeats = _seats
        .where(
          (seat) =>
              seat.action<LibbookReserveAction>()?.eligibility ==
              ActionEligibility.allowed,
        )
        .toList(growable: false);
    final loading = widget.snapshot.status == FeatureLoadStatus.loading;
    final failed = widget.snapshot.status == FeatureLoadStatus.failure;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (loading && _view == FeatureQueryView.summary)
                const _LibbookInlineLoading('正在加载图书馆楼馆...')
              else if (failed && _view == FeatureQueryView.summary)
                _LibbookInlineError(onRetry: _refreshReserve),
              _LibbookSection(
                title: '楼馆',
                trailing: IconButton(
                  onPressed: loading ? null : _refreshReserve,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
                children: [
                  for (final library in _libraries)
                    FilterChip(
                      selected: _libraryId == _academicField(library, '馆 ID'),
                      label: Text(
                        '${library.title} ${_academicField(library, '空闲座位') ?? '-'}/${_academicField(library, '总座位') ?? '-'}',
                      ),
                      onSelected: (_) => _selectLibrary(library),
                    ),
                ],
              ),
              if (storeys.isNotEmpty)
                _LibbookSection(
                  title: '楼层',
                  children: [
                    for (final storey in storeys)
                      FilterChip(
                        selected: _storeyId == storey.id,
                        label: Text(
                          '${storey.name} ${storey.free}/${storey.total}',
                        ),
                        onSelected: (_) => _selectStorey(storey.id),
                      ),
                  ],
                ),
              _LibbookSection(
                title: '分区',
                children: [
                  if (loading && _view == FeatureQueryView.libbookAreas)
                    const _LibbookInlineLoading('正在加载分区...')
                  else if (failed && _view == FeatureQueryView.libbookAreas)
                    _LibbookInlineError(onRetry: _refreshReserve)
                  else if (_areas.isEmpty)
                    const Text('当前楼层暂无可预约分区')
                  else
                    for (final area in _areas)
                      FilterChip(
                        selected: _areaId == _academicField(area, '分区 ID'),
                        label: Text(
                          '${area.title} ${_academicField(area, '空闲座位') ?? '-'}/${_academicField(area, '总座位') ?? '-'}',
                        ),
                        onSelected: (_) => _selectArea(area),
                      ),
                ],
              ),
              _LibbookSection(
                title: '座位',
                trailing: OutlinedButton(
                  onPressed: _areaMapAsset(_areaId) == null
                      ? null
                      : () => _showAreaMap(context),
                  child: const Text('查看座位分布'),
                ),
                children: [
                  if (_areaId != null && _areaMapAsset(_areaId) == null)
                    const Text('当前分区暂无平面图'),
                ],
              ),
              if (loading &&
                  (_view == FeatureQueryView.libbookAreaDetail ||
                      _view == FeatureQueryView.libbookSeats))
                const _LibbookInlineLoading('正在加载座位...')
              else if (failed &&
                  (_view == FeatureQueryView.libbookAreaDetail ||
                      _view == FeatureQueryView.libbookSeats))
                _LibbookInlineError(onRetry: _refreshReserve)
              else if (_seats.isEmpty)
                Text(
                  _areaDetails.firstOrNull != null &&
                          _slots(_areaDetails.first).isEmpty
                      ? '当前分区暂无可预约时段'
                      : '当前分区暂无座位数据',
                )
              else if (availableSeats.isEmpty)
                const Text('当前分区暂无可预约座位')
              else
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.15,
                  children: [
                    for (final seat in availableSeats)
                      if (seat.action<LibbookReserveAction>()
                          case final action?)
                        _LibbookSeatCard(
                          detail: seat,
                          selected: _selectedSeat == action,
                          onTap: () => setState(() => _selectedSeat = action),
                        ),
                  ],
                ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '预约信息',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('日期：${_day ?? '-'}'),
                      Text('分区：${_areaName ?? '-'}'),
                      Text(
                        '座位：${_selectedSeat == null ? '-' : _seatName(_selectedSeat!)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _selectedSeat == null || widget.onReserve == null
                    ? null
                    : () => widget.onReserve!(_selectedSeat!),
                child: const Text('确认预约'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookingList(BuildContext context) => Column(
    children: [
      if (widget.snapshot.status == FeatureLoadStatus.loading)
        const LinearProgressIndicator(),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '预约记录',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _query(
                    const FeatureQuery(
                      view: FeatureQueryView.libbookBookings,
                      page: 1,
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
              ],
            ),
            if (_bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('当前暂无图书馆座位预约'),
              )
            else
              for (final booking in _bookings)
                _LibbookBookingCard(detail: booking, onCancel: widget.onCancel),
          ],
        ),
      ),
    ],
  );

  void _selectLibrary(FeatureDetail library, {bool rebuild = true}) {
    final id = _academicField(library, '馆 ID');
    if (id == null) return;
    final storeys = _storeys(library);
    void update() {
      _libraryId = id;
      _storeyId = storeys.firstOrNull?.id;
      _areaId = null;
      _areas = [];
      _areaDetails = [];
      _seats = [];
      _selectedSeat = null;
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
    final query = FeatureQuery(
      view: FeatureQueryView.libbookAreas,
      premisesId: id,
      storeyId: _storeyId,
    );
    rebuild ? _query(query) : _queueQuery(query);
  }

  void _selectStorey(String? storeyId) {
    if (_libraryId == null) return;
    setState(() {
      _storeyId = storeyId;
      _areaId = null;
      _areas = [];
      _areaDetails = [];
      _seats = [];
      _selectedSeat = null;
    });
    _query(
      FeatureQuery(
        view: FeatureQueryView.libbookAreas,
        premisesId: _libraryId,
        storeyId: storeyId,
      ),
    );
  }

  void _selectArea(FeatureDetail area, {bool rebuild = true}) {
    final id = _academicField(area, '分区 ID');
    if (id == null) return;
    void update() {
      _areaId = id;
      _areaName = area.title;
      _areaDetails = [];
      _seats = [];
      _selectedSeat = null;
      _day = null;
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
    final query = FeatureQuery(
      view: FeatureQueryView.libbookAreaDetail,
      areaId: id,
    );
    rebuild ? _query(query) : _queueQuery(query);
  }

  void _selectSlot(_LibbookSlot slot, {bool rebuild = true}) {
    if (_areaId == null || _day == null) return;
    void update() {
      _segment = slot.id;
      _selectedSeat = null;
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
    final date = DateTime.tryParse(_day!);
    final query = FeatureQuery(
      view: FeatureQueryView.libbookSeats,
      areaId: _areaId,
      date: date,
      segment: slot.id,
      startTime: slot.start,
      endTime: slot.end,
    );
    rebuild ? _query(query) : _queueQuery(query);
  }

  Future<void> _refreshReserve() async {
    final detail = _areaDetails.firstOrNull;
    final slot = detail == null
        ? null
        : _slots(
            detail,
          ).where((candidate) => candidate.id == _segment).firstOrNull;
    if (_areaId != null && slot != null) {
      _selectSlot(slot);
      return;
    }
    if (_areaId != null) {
      await _query(
        FeatureQuery(view: FeatureQueryView.libbookAreaDetail, areaId: _areaId),
      );
      return;
    }
    if (_libraryId != null) {
      await _query(
        FeatureQuery(
          view: FeatureQueryView.libbookAreas,
          premisesId: _libraryId,
          storeyId: _storeyId,
        ),
      );
      return;
    }
    await _query(const FeatureQuery());
  }

  Future<void> _showAreaMap(BuildContext context) {
    final asset = _areaMapAsset(_areaId);
    if (asset == null) return Future.value();
    final controller = TransformationController();
    var viewport = Size.zero;
    void reset() => controller.value = Matrix4.identity();
    void zoom(double factor) {
      final scale = (controller.value.getMaxScaleOnAxis() * factor).clamp(
        1.0,
        5.0,
      );
      controller.value = Matrix4.diagonal3Values(scale, scale, 1)
        ..setEntry(0, 3, viewport.width * (1 - scale) / 2)
        ..setEntry(1, 3, viewport.height * (1 - scale) / 2);
    }

    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        _areaName ?? '座位分布',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '缩小',
                    onPressed: () => zoom(0.5),
                    icon: const Icon(Icons.zoom_out),
                  ),
                  IconButton(
                    tooltip: '放大',
                    onPressed: () => zoom(2),
                    icon: const Icon(Icons.zoom_in),
                  ),
                  TextButton(onPressed: reset, child: const Text('重置')),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  '静态座位分布图，颜色不代表当前可用状态。请在预约页面选择座位。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    viewport = constraints.biggest;
                    return InteractiveViewer(
                      transformationController: controller,
                      minScale: 1,
                      maxScale: 5,
                      trackpadScrollCausesScale: true,
                      onInteractionEnd: (_) {
                        if (controller.value.getMaxScaleOnAxis() <= 1.001)
                          reset();
                      },
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Image.asset(
                          asset,
                          package: 'ubaa_ui',
                          fit: BoxFit.contain,
                          semanticLabel: '静态座位分布图',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  List<_LibbookStorey> _storeys(FeatureDetail detail) {
    final result = <_LibbookStorey>[];
    for (var index = 1; ; index++) {
      final name = _academicField(detail, '楼层 $index');
      final id = _academicField(detail, '楼层 $index ID');
      if (name == null || id == null) break;
      result.add(
        _LibbookStorey(
          id,
          name,
          _academicField(detail, '楼层 $index 空闲') ?? '-',
          _academicField(detail, '楼层 $index 总数') ?? '-',
        ),
      );
    }
    return result;
  }

  List<_LibbookSlot> _slots(FeatureDetail detail) {
    final result = <_LibbookSlot>[];
    for (var index = 1; ; index++) {
      final id = _academicField(detail, '时段 $index ID');
      final start = _academicField(detail, '时段 $index 开始');
      final end = _academicField(detail, '时段 $index 结束');
      if (id == null || start == null || end == null) break;
      result.add(
        _LibbookSlot(
          id,
          start,
          end,
          _academicField(detail, '时段 $index') ?? '$start–$end',
        ),
      );
    }
    return result;
  }

  List<String> _splitField(String? value) =>
      value
          ?.split(RegExp(r'[、,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false) ??
      const [];

  String _seatName(LibbookReserveAction action) =>
      _seats
          .where((detail) => detail.action<LibbookReserveAction>() == action)
          .firstOrNull
          ?.title ??
      '-';
}

class _LibbookHomeCard extends StatelessWidget {
  const _LibbookHomeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LibbookSection extends StatelessWidget {
  const _LibbookSection({
    required this.title,
    required this.children,
    this.trailing,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (trailing case final widget?) widget,
        ],
      ),
      const SizedBox(height: 4),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              children[index],
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
    ],
  );
}

class _LibbookSeatCard extends StatelessWidget {
  const _LibbookSeatCard({
    required this.detail,
    required this.selected,
    required this.onTap,
  });
  final FeatureDetail detail;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              detail.subtitle?.isNotEmpty == true
                  ? detail.subtitle!
                  : detail.title,
              maxLines: 1,
            ),
            Text(
              selected ? '已选' : '可预约',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LibbookBookingCard extends StatelessWidget {
  const _LibbookBookingCard({required this.detail, this.onCancel});

  final FeatureDetail detail;
  final LibbookCancelStarter? onCancel;

  @override
  Widget build(BuildContext context) {
    final cancel = detail.action<LibbookCancelAction>();
    final canCancel =
        cancel?.eligibility == ActionEligibility.allowed && onCancel != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    detail.title.isEmpty ? '图书馆座位' : detail.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _academicField(detail, '状态') ?? '已预约',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                _academicField(detail, '日期'),
                _academicField(detail, '时段'),
              ].whereType<String>().join(' '),
            ),
            if (_academicField(detail, '座位') case final seat?) ...[
              const SizedBox(height: 8),
              Text('座位：$seat'),
            ],
            if (canCancel) ...[
              const SizedBox(height: 8),
              ActionChip(
                onPressed: () => onCancel!(cancel!),
                label: const Text('取消预约'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LibbookInlineLoading extends StatelessWidget {
  const _LibbookInlineLoading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 8),
      Text(text),
    ],
  );
}

class _LibbookInlineError extends StatelessWidget {
  const _LibbookInlineError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '加载失败',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      const SizedBox(width: 8),
      ActionChip(onPressed: onRetry, label: const Text('重试')),
    ],
  );
}

const _libbookMapAreaIds = <String>{
  '6',
  '8',
  '16',
  '18',
  '19',
  '20',
  '21',
  '22',
  '23',
  '24',
  '25',
  '26',
  '27',
  '28',
  '29',
  '52',
  '53',
  '63',
  '64',
  '65',
  '67',
  '68',
  '69',
  '71',
  '72',
  '73',
  '82',
  '83',
  '117',
};

String? _areaMapAsset(String? areaId) =>
    areaId != null && _libbookMapAreaIds.contains(areaId)
    ? 'assets/libbook/area_$areaId.jpg'
    : null;

String _libbookDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class _LibbookStorey {
  const _LibbookStorey(this.id, this.name, this.free, this.total);
  final String id;
  final String name;
  final String free;
  final String total;
}

class _LibbookSlot {
  const _LibbookSlot(this.id, this.start, this.end, this.label);
  final String id;
  final String start;
  final String end;
  final String label;
}
