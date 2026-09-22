part of '../widgets.dart';

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.user,
    required this.routePolicy,
    required this.telemetryEnabled,
    required this.onRoutePolicyChanged,
    required this.onTelemetryChanged,
    required this.onLogout,
    required this.onLogoutAndClearAccount,
    required this.activeRoutes,
    this.changingRoute = false,
    this.onReadDiagnostics,
    this.onLoadAppVersion,
    this.onOpenProject,
  });

  final UserSummary? user;
  final RoutePolicy routePolicy;
  final bool telemetryEnabled;
  final ValueChanged<RoutePolicy> onRoutePolicyChanged;
  final ValueChanged<bool> onTelemetryChanged;
  final Future<void> Function() onLogout;
  final Future<void> Function() onLogoutAndClearAccount;
  final List<ConnectionMode> activeRoutes;
  final bool changingRoute;
  final String Function()? onReadDiagnostics;
  final Future<String?> Function()? onLoadAppVersion;
  final Future<bool> Function()? onOpenProject;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 28,
            child: Text((user?.preferredName ?? 'U').characters.first),
          ),
          title: Text(user?.preferredName ?? context.tr('未登录')),
          subtitle: Text(user?.username ?? ''),
        ),
      ),
      const SizedBox(height: 16),
      if (AppearanceScope.of(context) != null) ...[
        Card(
          child: ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('语言')),
            subtitle: Text(
              _languageLabel(context, AppearanceScope.of(context)!.language),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _chooseLanguage(context),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.tr('界面与课表设置')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const AppearanceSettingsPage()),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      Card(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune),
                      const SizedBox(width: 16),
                      Expanded(child: Text(context.tr('连接模式'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      changingRoute ? '正在切换连接，请稍候…' : routePolicy.description,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<RoutePolicy>(
                    isExpanded: true,
                    value: routePolicy,
                    onChanged: changingRoute
                        ? null
                        : (value) {
                            if (value != null) onRoutePolicyChanged(value);
                          },
                    items: RoutePolicy.values
                        .map(
                          (item) => DropdownMenuItem<RoutePolicy>(
                            value: item,
                            child: Text(context.tr(item.label)),
                          ),
                        )
                        .toList(),
                  ),
                  if (changingRoute) const LinearProgressIndicator(),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(context.tr('已认证路线')),
              subtitle: Text(
                activeRoutes.isEmpty
                    ? context.tr('暂无已认证路线')
                    : activeRoutes
                          .map((route) => context.tr(route.label))
                          .join('、'),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.insights_outlined),
              title: Text(context.tr('匿名产品改进统计')),
              subtitle: Text(context.tr('仅统计功能使用次数，不收集账号、成绩或请求内容')),
              value: telemetryEnabled,
              onChanged: onTelemetryChanged,
            ),
            if (onReadDiagnostics != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(context.tr('本次运行诊断')),
                subtitle: Text(context.tr('查看或复制错误信息，不会自动上传')),
                onTap: () =>
                    _showDiagnosticsDialog(context, onReadDiagnostics!),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 24),
      Card(
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(context.tr('关于 UBAA')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => _AboutView(
                loadVersion: onLoadAppVersion,
                openProject: onOpenProject,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => onLogout(),
        icon: const Icon(Icons.logout),
        label: Text(context.tr('退出登录')),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => _confirmClearAccount(context),
        icon: const Icon(Icons.delete_outline),
        label: Text(context.tr('退出并清除本机账号')),
      ),
      const SizedBox(height: 32),
      Text(
        context.tr('UBAA 应用\nMake BUAA Great Again'),
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ],
  );

  String _languageLabel(BuildContext context, AppLanguage language) =>
      language == AppLanguage.system
      ? context.tr(language.label)
      : language.label;

  Future<void> _chooseLanguage(BuildContext context) async {
    final settings = AppearanceScope.of(context)!;
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.tr('语言')),
        children: [
          for (final language in AppLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, language),
              child: Row(
                children: [
                  Expanded(child: Text(_languageLabel(context, language))),
                  if (settings.language == language) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    settings.language = selected;
    try {
      await settings.save();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('设置保存失败，本次生效；请重试'))));
      }
    }
  }

  Future<void> _confirmClearAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('清除本机账号？')),
        content: Text(context.tr('这会退出登录，并删除你主动保存的账号密码；学校服务器上的数据不会被删除。')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('退出并清除')),
          ),
        ],
      ),
    );
    if (confirmed == true) await onLogoutAndClearAccount();
  }
}
