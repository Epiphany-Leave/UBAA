part of '../widgets.dart';

class _YgdkFormDialog extends StatefulWidget {
  const _YgdkFormDialog({required this.projects, required this.onPickPhoto});

  final List<FeatureDetail> projects;
  final YgdkPhotoPicker? onPickPhoto;

  @override
  State<_YgdkFormDialog> createState() => _YgdkFormDialogState();
}

class _YgdkFormDialogState extends State<_YgdkFormDialog> {
  static const _previewCacheWidth = 720;
  static const _previewCacheHeight = 480;

  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _placeController;
  YgdkPhotoInput? _photo;
  Uint8List? _previewBytes;
  String? _error;
  bool _picking = false;
  bool _shareToSquare = false;
  late FeatureDetail _project;

  @override
  void initState() {
    super.initState();
    _project = widget.projects.first;
    _startController = TextEditingController();
    _endController = TextEditingController();
    _placeController = TextEditingController(text: '操场');
  }

  @override
  void dispose() {
    _releasePhotoReferences();
    _startController.dispose();
    _endController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _cancel),
        title: Text(context.tr('填写阳光打卡信息')),
        actions: [
          TextButton(onPressed: _cancel, child: Text(context.tr('取消'))),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _section('运动项目', [
                DropdownButtonFormField<FeatureDetail>(
                  initialValue: _project,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final project in widget.projects)
                      DropdownMenuItem(
                        value: project,
                        child: Text(project.title),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _project = value);
                  },
                ),
              ]),
              _section('时间', [
                TextField(
                  controller: _startController,
                  decoration: InputDecoration(
                    labelText: context.tr('开始时间'),
                    hintText: 'YYYY-MM-DD HH:mm',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: context.tr('选择开始时间'),
                      icon: const Icon(Icons.schedule),
                      onPressed: () => _chooseTime(_startController),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _endController,
                  decoration: InputDecoration(
                    labelText: context.tr('结束时间'),
                    hintText: 'YYYY-MM-DD HH:mm',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: context.tr('选择结束时间'),
                      icon: const Icon(Icons.schedule),
                      onPressed: () => _chooseTime(_endController),
                    ),
                  ),
                ),
              ]),
              _section('地点', [
                TextField(
                  controller: _placeController,
                  decoration: InputDecoration(
                    labelText: context.tr('打卡地点'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.place_outlined),
                  ),
                ),
              ]),
              _section('照片', [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _picking || widget.onPickPhoto == null
                        ? null
                        : _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      _photo == null
                          ? context.tr('选择照片')
                          : context.tr("已选择照片：{0}", [_photo!.fileName]),
                    ),
                  ),
                ),
                if (_previewBytes case final bytes?) ...<Widget>[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      bytes,
                      key: const ValueKey<String>('ygdk-photo-preview'),
                      width: 180,
                      height: 120,
                      cacheWidth: _previewCacheWidth,
                      cacheHeight: _previewCacheHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => SizedBox(
                        width: 180,
                        height: 72,
                        child: Center(
                          child: Text(context.tr('照片预览不可用，请重新选择。')),
                        ),
                      ),
                    ),
                  ),
                ],
                if (widget.onPickPhoto == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.tr('当前运行环境未提供照片选择器，无法提交打卡。')),
                  ),
                CheckboxListTile(
                  value: _shareToSquare,
                  onChanged: (value) => setState(() {
                    _shareToSquare = value ?? false;
                  }),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('分享到打卡广场')),
                ),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr(message),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _picking ? null : _continue,
                child: Text(context.tr('继续确认')),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );

  Future<void> _chooseTime(TextEditingController controller) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    String pad(int n) => n.toString().padLeft(2, '0');
    controller.text =
        '${day.year}-${pad(day.month)}-${pad(day.day)} ${pad(time.hour)}:${pad(time.minute)}';
  }

  Future<void> _pickPhoto() async {
    final picker = widget.onPickPhoto;
    if (picker == null || _picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await picker();
      if (!mounted) return;
      setState(() {
        _releasePhotoReferences();
        _photo = picked;
        _previewBytes = picked == null
            ? null
            : Uint8List.fromList(picked.bytes);
        _error = picked == null ? '未选择照片，阳光打卡必须附带照片。' : null;
      });
    } on Object {
      if (mounted) {
        setState(() => _error = '照片选择失败，请检查平台权限后重试。');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _continue() {
    final start = _startController.text;
    final end = _endController.text;
    final photo = _photo;
    if (start.trim().isEmpty || end.trim().isEmpty || photo == null) {
      setState(() => _error = '请填写完整时间并选择照片。');
      return;
    }
    final input = YgdkSubmitInput(
      action: _project.action<YgdkSubmitAction>()!,
      startTime: start,
      endTime: end,
      place: _placeController.text.trim(),
      shareToSquare: _shareToSquare,
      photo: photo,
    );
    _releasePhotoReferences();
    Navigator.of(context).pop(input);
  }

  void _cancel() {
    _releasePhotoReferences();
    Navigator.of(context).pop();
  }

  void _releasePhotoReferences() {
    final bytes = _previewBytes;
    if (bytes != null) {
      unawaited(
        ResizeImage(
          MemoryImage(bytes),
          width: _previewCacheWidth,
          height: _previewCacheHeight,
        ).evict(cache: PaintingBinding.instance.imageCache),
      );
    }
    _previewBytes = null;
    _photo = null;
  }
}
