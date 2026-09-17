part of 'ubaa_app_host.dart';

class _UbaaAppHostState extends State<UbaaAppHost> with WidgetsBindingObserver {
  late final AppController _controller;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasBackgrounded = false;
  bool _resumeRecoveryPending = false;
  bool _recoveryInFlight = false;
  bool _openingOfflineSchedule = false;
  bool _hasSyncedScheduleWidget = false;
  bool _disposed = false;
  Timetable? _lastSyncedScheduleWidget;
  OfflineScheduleTarget? _pendingOfflineScheduleTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final backend = widget.backend;
    final backendFactory = widget.backendFactory ?? createProductionBackend;
    _controller = AppController(
      backend: backend ?? backendFactory(),
      backendFactory: backend == null ? backendFactory : null,
      credentialVault: widget.credentialVault,
      telemetry: widget.telemetry,
    );
    _controller.addListener(_onControllerChanged);
    widget.offlineScheduleTarget?.addListener(_onOfflineScheduleTarget);
    unawaited(_controller.initialize());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onOfflineScheduleTarget(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    widget.offlineScheduleTarget?.removeListener(_onOfflineScheduleTarget);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      if (widget.backend != null) return;
      _resumeRecoveryPending = true;
      _retryPendingRecovery();
    }
  }

  void _retryPendingRecovery() {
    if (_disposed || !_resumeRecoveryPending || _recoveryInFlight) return;
    if (_controller.isRebuildingBackend ||
        _controller.phase == AppPhase.loggingIn ||
        _controller.phase == AppPhase.checkingSession) {
      return;
    }
    _resumeRecoveryPending = false;
    _recoveryInFlight = true;
    unawaited(_recoverBackend());
  }

  void _onControllerChanged() {
    _retryPendingRecovery();
    _syncScheduleWidget();
    _tryOpenOfflineScheduleTarget();
  }

  void _syncScheduleWidget() {
    final sync = widget.syncScheduleWidget;
    if (sync == null ||
        _controller.phase == AppPhase.splash ||
        _controller.phase == AppPhase.checkingSession ||
        _controller.phase == AppPhase.loggingIn) {
      return;
    }
    final timetable = _controller.snapshots[FeatureId.schedule]?.timetable;
    // 已登录但尚未从 Core 读到缓存时保留旧快照，避免冷启动的短暂空白覆盖组件。
    if (_controller.phase == AppPhase.home && timetable == null) return;
    if (_hasSyncedScheduleWidget &&
        identical(timetable, _lastSyncedScheduleWidget)) {
      return;
    }
    _hasSyncedScheduleWidget = true;
    _lastSyncedScheduleWidget = timetable;
    unawaited(_syncScheduleWidgetSafely(sync, timetable));
  }

  Future<void> _syncScheduleWidgetSafely(
    Future<void> Function(Timetable? timetable) sync,
    Timetable? timetable,
  ) async {
    try {
      await sync(timetable);
    } on Object {
      // Android 小组件不能影响主应用的登录、缓存或课表浏览。
    }
  }

  void _onOfflineScheduleTarget() {
    final target = widget.offlineScheduleTarget?.value;
    if (target == null) return;
    widget.offlineScheduleTarget!.value = null;
    _pendingOfflineScheduleTarget = target;
    _tryOpenOfflineScheduleTarget();
  }

  void _tryOpenOfflineScheduleTarget() {
    if (_disposed ||
        _openingOfflineSchedule ||
        _pendingOfflineScheduleTarget == null ||
        (_controller.phase != AppPhase.login &&
            _controller.phase != AppPhase.home)) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tryOpenOfflineScheduleTarget(),
      );
      return;
    }
    final target = _pendingOfflineScheduleTarget!;
    _pendingOfflineScheduleTarget = null;
    _openingOfflineSchedule = true;
    unawaited(_openScheduledWidgetTarget(context, target));
  }

  Future<void> _openScheduledWidgetTarget(
    BuildContext context,
    OfflineScheduleTarget target,
  ) async {
    try {
      await _openOfflineSchedule(context, target);
    } finally {
      _openingOfflineSchedule = false;
      _tryOpenOfflineScheduleTarget();
    }
  }

  Future<void> _recoverBackend() async {
    try {
      await _controller.rebuildBackend();
    } finally {
      _recoveryInFlight = false;
      if (!_disposed) _retryPendingRecovery();
    }
  }

  @override
  Widget build(BuildContext context) => _buildApplication();
}
