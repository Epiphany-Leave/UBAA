part of '../widgets.dart';

class _AboutView extends StatefulWidget {
  const _AboutView({this.loadVersion, this.openProject});

  final Future<String?> Function()? loadVersion;
  final Future<bool> Function()? openProject;

  @override
  State<_AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<_AboutView> {
  late Future<String?> _version = _loadVersion();

  Future<String?> _loadVersion() async {
    try {
      return await widget.loadVersion?.call();
    } on Object {
      return null;
    }
  }

  Future<void> _openProject() async {
    try {
      if (await widget.openProject?.call() == true) return;
    } on Object {
      // The URL remains available when the host has no browser handler.
    }
    if (!mounted) return;
    const url = 'https://github.com/BUAASubnet/UBAA';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('请在浏览器打开')),
        content: const SelectableText(url),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: url));
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.tr('复制地址')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('关闭')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('关于 UBAA'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('UBAA', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(context.tr('Make BUAA Great Again\n北航校园服务应用')),
        const SizedBox(height: 24),
        FutureBuilder<String?>(
          future: _version,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final version = snapshot.data;
            return ListTile(
              leading: const Icon(Icons.tag),
              title: Text(context.tr('当前安装版本')),
              subtitle: Text(
                loading
                    ? context.tr('读取中…')
                    : version ?? context.tr('当前平台暂无法读取版本'),
              ),
              trailing: !loading && version == null
                  ? IconButton(
                      tooltip: context.tr('重试读取版本'),
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() {
                        _version = _loadVersion();
                      }),
                    )
                  : null,
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.open_in_new),
          title: Text(context.tr('项目主页')),
          onTap: _openProject,
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(context.tr('开源许可')),
          onTap: () =>
              showLicensePage(context: context, applicationName: 'UBAA'),
        ),
      ],
    ),
  );
}
