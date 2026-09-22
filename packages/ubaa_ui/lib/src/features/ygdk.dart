part of '../widgets.dart';

class _YgdkHeader extends StatelessWidget {
  const _YgdkHeader({required this.snapshot, required this.onQuery});
  final FeatureSnapshot snapshot;
  final Future<void> Function(FeatureQuery) onQuery;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                snapshot.status == FeatureLoadStatus.failure
                    ? ''
                    : snapshot.summary ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              width: 60,
              height: 56,
              child: _FeatureQueryControls(
                feature: FeatureId.ygdk,
                details: snapshot.details,
                onApply: onQuery,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: snapshot.status == FeatureLoadStatus.loading
                  ? null
                  : () => onQuery(const FeatureQuery()),
              icon: const Icon(Icons.directions_run),
              label: Text(context.tr('打卡概览')),
            ),
            OutlinedButton.icon(
              onPressed: snapshot.status == FeatureLoadStatus.loading
                  ? null
                  : () => onQuery(
                      const FeatureQuery(
                        view: FeatureQueryView.ygdkRecords,
                        page: 1,
                      ),
                    ),
              icon: const Icon(Icons.history),
              label: Text(context.tr('历史记录')),
            ),
          ],
        ),
      ],
    ),
  );
}

class _YgdkRecordCard extends StatelessWidget {
  const _YgdkRecordCard(this.detail);
  final FeatureDetail detail;

  @override
  Widget build(BuildContext context) {
    final start = _academicField(detail, '开始时间');
    final end = _academicField(detail, '结束时间');
    final place = _academicField(detail, '地点');
    final time = [start, end].whereType<String>().join(' — ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('记录详情')),
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
                children: [
                  const Icon(Icons.directions_run),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detail.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (place != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(place)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(time.isEmpty ? context.tr('时间未提供') : time),
              const SizedBox(height: 8),
              Text(
                [
                  if (detail.subtitle != null)
                    context.tr("提交于 {0}", [detail.subtitle]),
                  if (_academicField(detail, '图片数量') case final count?)
                    context.tr("{0} 张图片", [count]),
                  if (_academicField(detail, '公开状态') case final visibility?)
                    visibility,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _YgdkQueryControls on _FeatureQueryControlsState {
  List<Widget> _ygdkQueryFields(StateSetter setState) => <Widget>[
    if (widget.feature == FeatureId.ygdk) ...<Widget>[
      DropdownButton<FeatureQueryView>(
        value: _ygdkView,
        onChanged: _submitting
            ? null
            : (value) =>
                  setState(() => _ygdkView = value ?? FeatureQueryView.summary),
        items: <DropdownMenuItem<FeatureQueryView>>[
          DropdownMenuItem(
            value: FeatureQueryView.summary,
            child: Text(context.tr('概览')),
          ),
          DropdownMenuItem(
            value: FeatureQueryView.ygdkRecords,
            child: Text(context.tr('记录列表')),
          ),
        ],
      ),
      if (_ygdkView == FeatureQueryView.ygdkRecords) ...<Widget>[
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
    ],
  ];
}

class _YgdkPage extends StatefulWidget {
  const _YgdkPage({
    required this.snapshot,
    required this.child,
    this.query,
    this.onQuery,
    this.onSubmit,
    this.onPickPhoto,
    this.loadReminder,
    this.saveReminder,
  });
  final FeatureSnapshot snapshot;
  final FeatureQuery? query;
  final Widget child;
  final Future<void> Function(FeatureQuery)? onQuery;
  final YgdkSubmitStarter? onSubmit;
  final YgdkPhotoPicker? onPickPhoto;
  final Future<bool> Function()? loadReminder;
  final Future<void> Function(bool)? saveReminder;

  @override
  State<_YgdkPage> createState() => _YgdkPageState();
}

class _YgdkPageState extends State<_YgdkPage> {
  List<FeatureDetail> _projects = const [];
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _rememberProjects();
  }

  @override
  void didUpdateWidget(covariant _YgdkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberProjects();
  }

  void _rememberProjects() {
    if ((widget.query?.view ?? FeatureQueryView.summary) !=
        FeatureQueryView.summary)
      return;
    if (widget.snapshot.status != FeatureLoadStatus.success &&
        widget.snapshot.status != FeatureLoadStatus.empty)
      return;
    _projects = widget.snapshot.details
        .where(
          (detail) =>
              detail.action<YgdkSubmitAction>()?.hasCanonicalTarget == true,
        )
        .toList();
  }

  Future<void> _openForm() async {
    setState(() => _opening = true);
    try {
      if (_projects.isEmpty && widget.onQuery != null) {
        await widget.onQuery!(const FeatureQuery());
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      if (_projects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('暂无可提交的打卡项目，请刷新概览后重试。'))),
        );
        return;
      }
      final input = await showDialog<YgdkSubmitInput>(
        context: context,
        builder: (_) => _YgdkFormDialog(
          projects: List.unmodifiable(_projects),
          onPickPhoto: widget.onPickPhoto,
        ),
      );
      if (input != null && mounted) await widget.onSubmit?.call(input);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('暂时无法打开打卡，请重试。'))));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.onQuery != null)
        _YgdkHeader(snapshot: widget.snapshot, onQuery: widget.onQuery!),
      if (widget.loadReminder != null && widget.saveReminder != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _YgdkHomeReminder(
            settings: true,
            load: widget.loadReminder!,
            save: widget.saveReminder!,
          ),
        ),
      Expanded(child: widget.child),
      if (widget.onSubmit != null &&
          (_projects.isNotEmpty || widget.onQuery != null))
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed:
                    _opening ||
                        widget.snapshot.status == FeatureLoadStatus.loading
                    ? null
                    : _openForm,
                icon: const Icon(Icons.add),
                label: Text(context.tr('去打卡')),
              ),
            ),
          ),
        ),
    ],
  );
}
