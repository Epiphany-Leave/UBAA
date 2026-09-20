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
        if (snapshot.summary != null &&
            snapshot.status != FeatureLoadStatus.failure)
          Text(
            snapshot.summary!,
            style: Theme.of(context).textTheme.titleLarge,
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

extension _YgdkDetailActions on _FeatureDetailListState {
  List<Widget> _ygdkWriteFields(
    BuildContext context,
    YgdkSubmitAction? ygdkAction,
    FeatureDetail detail,
  ) => <Widget>[
    if (ygdkAction != null && widget.onYgdkSubmitWrite != null) ...<Widget>[
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () =>
            _showYgdkForm(context, action: ygdkAction, title: detail.title),
        icon: const Icon(Icons.directions_run),
        label: Text(context.tr('准备阳光打卡')),
      ),
    ],
  ];

  YgdkSubmitAction? _ygdkAction(FeatureDetail detail) {
    if (widget.feature != FeatureId.ygdk) return null;
    final action = detail.action<YgdkSubmitAction>();
    return action?.hasCanonicalTarget == true ? action : null;
  }
}
