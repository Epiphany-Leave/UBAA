part of '../widgets.dart';

class _ClassroomView extends StatefulWidget {
  const _ClassroomView({
    required this.snapshot,
    required this.onQuery,
    this.initialQuery,
  });

  final FeatureSnapshot snapshot;
  final FeatureQuery? initialQuery;
  final Future<void> Function(FeatureQuery) onQuery;

  @override
  State<_ClassroomView> createState() => _ClassroomViewState();
}

class _ClassroomViewState extends State<_ClassroomView> {
  late int _campus;
  late DateTime _date;
  String _search = '';
  String? _building;

  @override
  void initState() {
    super.initState();
    _campus = widget.initialQuery?.campus ?? 1;
    final now = DateTime.now();
    _date = widget.initialQuery?.date ?? DateTime(now.year, now.month, now.day);
  }

  List<String> get _buildings =>
      widget.snapshot.details
          .map((detail) => detail.subtitle?.trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort(_naturalCompare);

  Future<void> _load({int? campus, DateTime? date}) async {
    setState(() {
      _campus = campus ?? _campus;
      _date = date ?? _date;
      _building = null;
    });
    await widget.onQuery(FeatureQuery(campus: _campus, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    final buildings = _buildings;
    final selectedBuilding = buildings.contains(_building)
        ? _building
        : buildings.firstOrNull;
    final query = _search.trim().toLowerCase();
    final visible = widget.snapshot.details
        .where((detail) {
          final building = detail.subtitle?.trim() ?? '';
          if (building != selectedBuilding) return false;
          return query.isEmpty ||
              building.toLowerCase().contains(query) ||
              detail.title.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final grouped = <String, List<FeatureDetail>>{};
    for (final room in visible) {
      grouped.putIfAbsent(room.subtitle?.trim() ?? '其他教室', () => []).add(room);
    }
    for (final rooms in grouped.values) {
      rooms.sort((a, b) => _naturalCompare(a.title, b.title));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final campus in const [(1, '学院路'), (2, '沙河'), (3, '杭州')])
                FilterChip(
                  selected: _campus == campus.$1,
                  onSelected: (_) => _load(campus: campus.$1),
                  label: Text(context.tr(campus.$2)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035, 12, 31),
                    );
                    if (selected != null) await _load(date: selected);
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(_dateText(_date)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.tr('搜索教室/楼栋'),
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
            ],
          ),
        ),
        if (_buildings.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _buildings.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final building = _buildings[index];
                return FilterChip(
                  selected: selectedBuilding == building,
                  onSelected: (_) => setState(() => _building = building),
                  label: Text(building),
                );
              },
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: Color(0xff98fb98)),
                child: SizedBox.square(dimension: 12),
              ),
              SizedBox(width: 6),
              Text(context.tr('空闲')),
            ],
          ),
        ),
        if (widget.snapshot.status == FeatureLoadStatus.loading)
          const LinearProgressIndicator(),
        if (widget.snapshot.status == FeatureLoadStatus.stale)
          MaterialBanner(
            content: Text(context.tr('刷新失败，仍显示上次查询结果')),
            actions: [],
          ),
        Expanded(
          child: switch (widget.snapshot.status) {
            FeatureLoadStatus.loading when widget.snapshot.details.isEmpty =>
              Center(child: Text(context.tr('正在查询…'))),
            FeatureLoadStatus.failure => Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('查询失败，重试')),
              ),
            ),
            _ when grouped.isEmpty => Center(
              child: Text(context.tr('未找到匹配教室')),
            ),
            _ => _ClassroomTable(grouped: grouped),
          },
        ),
      ],
    );
  }

  String _dateText(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ClassroomTable extends StatelessWidget {
  const _ClassroomTable({required this.grouped});

  final Map<String, List<FeatureDetail>> grouped;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPersistentHeader(
        pinned: true,
        delegate: _ClassroomHeaderDelegate(
          color: Theme.of(context).colorScheme.surface,
        ),
      ),
      SliverList.list(
        children: [
          for (final entry in grouped.entries) ...[
            for (final room in entry.value) _ClassroomTableRow(room: room),
          ],
          const SizedBox(height: 16),
        ],
      ),
    ],
  );
}

class _ClassroomHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ClassroomHeaderDelegate({required this.color});
  final Color color;

  @override
  double get minExtent => 40;
  @override
  double get maxExtent => 40;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: color, child: const _ClassroomTableRow(header: true));
  @override
  bool shouldRebuild(_ClassroomHeaderDelegate oldDelegate) =>
      oldDelegate.color != color;
}

class _ClassroomTableRow extends StatelessWidget {
  const _ClassroomTableRow({this.room, this.header = false});

  final FeatureDetail? room;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final free = (room == null ? '' : _academicField(room!, '可用节次') ?? '')
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toSet();
    final border = Border.all(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: .5,
    );
    return SizedBox(
      height: header ? 40 : 44,
      child: Row(
        children: [
          Expanded(
            flex: 22,
            child: Container(
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: border),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                header ? context.tr('教室') : room!.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          for (var section = 1; section <= 14; section++)
            Expanded(
              flex: 10,
              child: Semantics(
                label: header
                    ? context.tr("第{0}节", [section])
                    : context.tr("{0}第{1}节{2}", [
                        room!.title,
                        section,
                        free.contains(section) ? '空闲' : '占用',
                      ]),
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: border,
                    color: !header && free.contains(section)
                        ? const Color(0xff98fb98)
                        : null,
                  ),
                  child: header
                      ? Text('$section', style: const TextStyle(fontSize: 9))
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

int _naturalCompare(String left, String right) {
  final expression = RegExp(r'(\d+)|(\D+)');
  final a = expression
      .allMatches(left)
      .map((match) => match.group(0)!)
      .toList();
  final b = expression
      .allMatches(right)
      .map((match) => match.group(0)!)
      .toList();
  for (var index = 0; index < a.length && index < b.length; index++) {
    final aNumber = int.tryParse(a[index]);
    final bNumber = int.tryParse(b[index]);
    final result = aNumber != null && bNumber != null
        ? aNumber.compareTo(bNumber)
        : a[index].compareTo(b[index]);
    if (result != 0) return result;
  }
  return a.length.compareTo(b.length);
}
