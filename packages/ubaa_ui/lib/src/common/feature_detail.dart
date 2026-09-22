part of '../widgets.dart';

class _FeatureDetailView extends StatelessWidget {
  const _FeatureDetailView({
    required this.feature,
    required this.snapshot,
    required this.subpage,
    required this.onSubpageChanged,
    this.query,
    this.timetable,
    required this.onRetry,
    this.onBykcWrite,
    this.boyaCalendar,
    this.onBykcSignWrite,
    this.onSigninWrite,
    this.onCgyyCancelWrite,
    this.onLibbookReserveWrite,
    this.onLibbookCancelWrite,
    this.onCgyySubmitWrite,
    this.onEvaluationWrite,
    this.onYgdkSubmitWrite,
    this.onPickYgdkPhoto,
    this.onLoadYgdkReminder,
    this.onSaveYgdkReminder,
    this.onQuery,
  });

  final FeatureId feature;
  final FeatureSnapshot snapshot;
  final _FeatureSubpage? subpage;
  final ValueChanged<_FeatureSubpage?> onSubpageChanged;
  final FeatureQuery? query;
  final Timetable? timetable;
  final Future<void> Function() onRetry;
  final Future<void> Function(WriteOperation operation, int courseId)?
  onBykcWrite;
  final BykcSignStarter? onBykcSignWrite;
  final BoyaCalendarActions? boyaCalendar;
  final SigninStarter? onSigninWrite;
  final CgyyCancelStarter? onCgyyCancelWrite;
  final LibbookReserveStarter? onLibbookReserveWrite;
  final LibbookCancelStarter? onLibbookCancelWrite;
  final CgyyReservationStarter? onCgyySubmitWrite;
  final EvaluationSubmitStarter? onEvaluationWrite;
  final YgdkSubmitStarter? onYgdkSubmitWrite;
  final YgdkPhotoPicker? onPickYgdkPhoto;
  final Future<bool> Function()? onLoadYgdkReminder;
  final Future<void> Function(bool)? onSaveYgdkReminder;
  final Future<void> Function(FeatureQuery query)? onQuery;

  @override
  Widget build(BuildContext context) {
    if (feature == FeatureId.schedule && onQuery != null) {
      return TimetableView(snapshot: snapshot, onQuery: onQuery!);
    }
    if (feature == FeatureId.classroom && onQuery != null) {
      return _ClassroomView(
        snapshot: snapshot,
        initialQuery: query,
        onQuery: onQuery!,
      );
    }
    if (feature == FeatureId.libbook && onQuery != null) {
      return _LibbookView(
        snapshot: snapshot,
        initialQuery: query,
        page: subpage,
        onPageChanged: onSubpageChanged,
        onQuery: onQuery!,
        onReserve: onLibbookReserveWrite,
        onCancel: onLibbookCancelWrite,
      );
    }
    if (feature == FeatureId.bykc && onQuery != null) {
      return _BykcView(
        calendar: boyaCalendar,
        snapshot: snapshot,
        initialQuery: query,
        page: subpage,
        onPageChanged: onSubpageChanged,
        onQuery: onQuery!,
        onWrite: onBykcWrite,
        onSignWrite: onBykcSignWrite,
      );
    }
    if (feature == FeatureId.cgyy && onQuery != null) {
      return _CgyyView(
        snapshot: snapshot,
        initialQuery: query,
        page: subpage,
        onPageChanged: onSubpageChanged,
        onQuery: onQuery!,
        onReserve: onCgyySubmitWrite,
        onCancel: onCgyyCancelWrite,
      );
    }
    Widget page(List<FeatureDetail> details) {
      final content = switch (snapshot.status) {
        FeatureLoadStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        FeatureLoadStatus.failure => _error(context),
        // A failed day switch must never offer the previous day's signing target.
        FeatureLoadStatus.stale =>
          feature == FeatureId.signin
              ? _error(context)
              : _stale(context, details),
        FeatureLoadStatus.empty => _empty(context),
        FeatureLoadStatus.idle => _empty(context),
        FeatureLoadStatus.success => _details(context, details),
      };
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: feature == FeatureId.ygdk
                ? _YgdkPage(
                    snapshot: snapshot,
                    query: query,
                    onQuery: onQuery,
                    onSubmit: onYgdkSubmitWrite,
                    onPickPhoto: onPickYgdkPhoto,
                    loadReminder: onLoadYgdkReminder,
                    saveReminder: onSaveYgdkReminder,
                    child: content,
                  )
                : feature == FeatureId.signin && onQuery != null
                ? Column(
                    children: [
                      _SigninDateHeader(
                        snapshot: snapshot,
                        timetable: timetable,
                        query: query ?? const FeatureQuery(),
                        onQuery: onQuery!,
                        busy: snapshot.status == FeatureLoadStatus.loading,
                      ),
                      Expanded(child: content),
                    ],
                  )
                : const {
                    FeatureId.grades,
                    FeatureId.exam,
                    FeatureId.spoc,
                    FeatureId.judge,
                  }.contains(feature)
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 64, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                snapshot.updatedAt == null
                                    ? '首次加载后保存，之后可手动刷新'
                                    : '数据时间：${snapshot.updatedAt!.toLocal().toString().split('.').first}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              tooltip: '刷新本地数据',
                              onPressed:
                                  snapshot.status == FeatureLoadStatus.loading
                                  ? null
                                  : () => onRetry(),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          if (onQuery != null &&
              _supportsQuery &&
              feature != FeatureId.signin &&
              feature != FeatureId.ygdk)
            Positioned.fill(
              child: _FeatureQueryControls(
                feature: feature,
                details: snapshot.details,
                scheduleNavigation: snapshot.scheduleNavigation,
                onApply: (value) => onQuery!(
                  feature == FeatureId.signin
                      ? value.copyWith(date: query?.date)
                      : value,
                ),
              ),
            ),
        ],
      );
    }

    return _alwaysShowsSearch
        ? _SearchableAcademicList(details: snapshot.details, builder: page)
        : page(snapshot.details);
  }

  bool get _alwaysShowsSearch => switch (feature) {
    FeatureId.exam ||
    FeatureId.grades ||
    FeatureId.spoc ||
    FeatureId.judge => true,
    _ => false,
  };

  bool get _supportsQuery => switch (feature) {
    FeatureId.schedule ||
    FeatureId.exam ||
    FeatureId.grades ||
    FeatureId.classroom ||
    FeatureId.bykc ||
    FeatureId.libbook ||
    FeatureId.ygdk ||
    FeatureId.cgyy ||
    FeatureId.signin ||
    FeatureId.spoc ||
    FeatureId.judge ||
    FeatureId.evaluation => true,
  };

  Widget _details(BuildContext context, List<FeatureDetail> details) {
    if (details.isEmpty) return _empty(context);
    return _detailsList(details);
  }

  Widget _detailsList(List<FeatureDetail> details) {
    if (feature == FeatureId.exam) {
      return _ExamList(details: details);
    }
    if (feature == FeatureId.grades) {
      return _GradesList(details: details);
    }
    return _FeatureDetailList(
      feature: feature,
      details: details,
      showSearchButton: !_alwaysShowsSearch,
      pagination: snapshot.pagination,
      query: query,
      onQuery: onQuery,
      onBykcWrite: onBykcWrite,
      onBykcSignWrite: onBykcSignWrite,
      onSigninWrite: onSigninWrite,
      onCgyyCancelWrite: onCgyyCancelWrite,
      onLibbookReserveWrite: onLibbookReserveWrite,
      onLibbookCancelWrite: onLibbookCancelWrite,
      onCgyySubmitWrite: onCgyySubmitWrite,
      onEvaluationWrite: onEvaluationWrite,
    );
  }

  Widget _stale(BuildContext context, List<FeatureDetail> details) {
    return Column(
      children: <Widget>[
        MaterialBanner(
          content: Text(
            context.tr(snapshot.error?.message ?? '刷新失败，以下是上次成功加载的数据。'),
          ),
          leading: const Icon(Icons.sync_problem),
          actions: <Widget>[
            TextButton(
              onPressed: () => onRetry(),
              child: Text(context.tr('重试')),
            ),
          ],
        ),
        Expanded(
          child: details.isEmpty ? _empty(context) : _detailsList(details),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _featureIcon(feature),
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(context.tr("暂无{0}数据", [context.tr(feature.title)])),
          if (snapshot.summary case final summary?
              when summary.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(summary, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );

  Widget _error(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: FriendlyErrorCard(
          error:
              snapshot.error ??
              const UiError(
                code: UbaaErrorCode.internalError,
                title: '加载失败',
                message: '暂时无法加载该功能，请稍后重试。',
                retryable: true,
              ),
          onRetry: () => onRetry(),
        ),
      ),
    ),
  );
}
