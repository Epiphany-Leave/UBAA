part of '../app_controller.dart';

extension _AppControllerRefresh on AppController {
  Future<void> _refreshHome({
    Iterable<FeatureId>? only,
    bool refresh = true,
  }) async {
    if (_disposed || _changingRoute) return;
    final lifecycleEpoch = _lifecycleEpoch;
    final features =
        (only ??
                (refresh
                    ? FeatureId.values
                    : const [
                        FeatureId.schedule,
                        FeatureId.exam,
                        FeatureId.grades,
                        FeatureId.spoc,
                        FeatureId.judge,
                      ]))
            .toList(growable: false);
    final generations = <FeatureId, int>{
      for (final feature in features) feature: _nextFeatureGeneration(feature),
    };
    final ygdkGeneration = features.contains(FeatureId.ygdk)
        ? ++_ygdkGeneration
        : null;
    for (final feature in features) {
      _snapshots[feature] = _snapshots[feature]!.copyWith(
        status: FeatureLoadStatus.loading,
        clearError: true,
      );
    }
    _notify();
    await Future.wait(
      features.map(
        (feature) => _loadFeature(
          feature,
          generations[feature]!,
          lifecycleEpoch,
          query:
              _backend is FeatureQueryBackend &&
                  const {
                    FeatureId.grades,
                    FeatureId.exam,
                    FeatureId.spoc,
                    FeatureId.judge,
                    FeatureId.signin,
                  }.contains(feature)
              ? FeatureQuery(refresh: refresh)
              : null,
          ygdkGeneration: feature == FeatureId.ygdk ? ygdkGeneration : null,
        ),
      ),
    );
  }

  /// 对支持 [FeatureQueryBackend] 的生产实现执行单领域筛选读取。
  ///
  /// 不支持查询的 fake backend 明确报 unsupported，不会在 Dart 端拼接请求。
  Future<void> _refreshFeatureQuery(
    FeatureId feature,
    FeatureQuery query,
  ) async {
    if (_disposed || _changingRoute) return;
    if (_backend is! FeatureQueryBackend) {
      _snapshots[feature] = _snapshots[feature]!.copyWith(
        status: FeatureLoadStatus.failure,
        error: UbaaErrorMapper.fromCode(UbaaErrorCode.unsupported),
      );
      _notify();
      return;
    }
    final lifecycleEpoch = _lifecycleEpoch;
    final generation = _nextFeatureGeneration(feature);
    final ygdkGeneration = feature == FeatureId.ygdk ? ++_ygdkGeneration : null;
    _snapshots[feature] = _snapshots[feature]!.copyWith(
      status: FeatureLoadStatus.loading,
      clearError: true,
    );
    _notify();
    await _loadFeature(
      feature,
      generation,
      lifecycleEpoch,
      query: query,
      ygdkGeneration: ygdkGeneration,
    );
  }

  int _nextFeatureGeneration(FeatureId feature) {
    final next = (_featureRefreshGenerations[feature] ?? 0) + 1;
    _featureRefreshGenerations[feature] = next;
    return next;
  }

  Future<void> _loadFeature(
    FeatureId feature,
    int generation,
    int lifecycleEpoch, {
    FeatureQuery? query,
    int? ygdkGeneration,
  }) async {
    // loading 通知可能同步触发注销或切换路线，发请求前再次核对归属。
    if (!_isFeatureLoadCurrent(
      feature,
      generation,
      lifecycleEpoch,
      ygdkGeneration,
    )) {
      return;
    }
    final started = DateTime.now();
    final previous = _snapshots[feature]!;
    final hadPreviousData = previous.updatedAt != null;
    try {
      final result = switch ((_backend, query)) {
        (FeatureQueryBackend queryBackend, final FeatureQuery value) =>
          await queryBackend.loadFeatureQuery(feature, value),
        _ => await _backend.loadFeature(feature),
      };
      if (!_applyFeatureResultIfCurrent(
        feature,
        result,
        generation,
        lifecycleEpoch,
        ygdkGeneration: ygdkGeneration,
      )) {
        return;
      }
      await _recordFeature(
        feature,
        success: result.error == null && !result.isEmpty,
        empty: result.isEmpty,
        error: _snapshots[feature]!.error,
        latency: DateTime.now().difference(started),
      );
      if (feature == FeatureId.grades &&
          (query == null ||
              (query.view == FeatureQueryView.summary && query.term == null)) &&
          _isFeatureLoadCurrent(
            feature,
            generation,
            lifecycleEpoch,
            ygdkGeneration,
          )) {
        _observeGradeDisplay(result);
      }
    } on Object catch (error, stackTrace) {
      if (!_isFeatureLoadCurrent(
        feature,
        generation,
        lifecycleEpoch,
        ygdkGeneration,
      )) {
        return;
      }
      final uiError = _recordFailure(
        error,
        DiagnosticOperation.read,
        stackTrace: stackTrace,
        feature: feature,
        latency: DateTime.now().difference(started),
      );
      _snapshots[feature] = _snapshots[feature]!.copyWith(
        status: hadPreviousData
            ? FeatureLoadStatus.stale
            : FeatureLoadStatus.failure,
        error: uiError,
      );
      await _recordFeature(
        feature,
        error: uiError,
        latency: DateTime.now().difference(started),
      );
    }
    _notify();
  }

  void _observeGradeDisplay(FeatureResult result) {
    if (result.error != null || result.resolvedRoute == null) return;
    if (_gradeScoreRoute != result.resolvedRoute) {
      _gradeScores.clear();
      _gradeChangeCount = 0;
      _gradeScoreRoute = result.resolvedRoute;
    }
    final latest = <(String, String), String?>{};
    final duplicates = <(String, String)>{};
    for (final detail in result.details) {
      String? field(String label) {
        for (final field in detail.fields) {
          if (field.label == label) return field.value.trim();
        }
        return null;
      }

      final code = detail.subtitle?.trim(), term = field('学期');
      if (code == null || code.isEmpty || term == null || term.isEmpty)
        continue;
      final key = (term, code);
      if (latest.containsKey(key)) duplicates.add(key);
      latest[key] = field('成绩');
    }
    for (final key in duplicates) {
      latest.remove(key);
      _gradeScores.remove(key);
    }
    var changes = 0;
    for (final entry in latest.entries) {
      if (_gradeScores.containsKey(entry.key) &&
          entry.value?.isNotEmpty == true &&
          entry.value != _gradeScores[entry.key])
        changes++;
    }
    // Empty/partial responses cannot invent deleted grades or erase a baseline.
    for (final entry in latest.entries) {
      if (!_gradeScores.containsKey(entry.key) ||
          entry.value?.isNotEmpty == true) {
        _gradeScores[entry.key] = entry.value;
      }
    }
    if (changes > 0) _gradeChangeCount = changes;
  }

  bool _applyFeatureResultIfCurrent(
    FeatureId feature,
    FeatureResult result,
    int generation,
    int lifecycleEpoch, {
    int? ygdkGeneration,
  }) {
    if (!_isFeatureLoadCurrent(
      feature,
      generation,
      lifecycleEpoch,
      ygdkGeneration,
    )) {
      return false;
    }
    final status = result.error != null
        ? FeatureLoadStatus.failure
        : result.isEmpty
        ? FeatureLoadStatus.empty
        : FeatureLoadStatus.success;
    _snapshots[feature] = _snapshots[feature]!.copyWith(
      status: status,
      summary: result.summary,
      details: result.details,
      scheduleNavigation: result.scheduleNavigation,
      timetable: result.timetable,
      signinDays: result.signinDays,
      clearTimetable: result.timetable == null,
      error: result.error == null
          ? null
          : _recordFailure(
              result.error!,
              DiagnosticOperation.read,
              feature: feature,
            ),
      resolvedRoute: result.resolvedRoute,
      pagination: result.pagination,
      updatedAt: result.savedAt ?? DateTime.now(),
      clearError: result.error == null,
      clearSummary: result.summary == null,
      clearDetails: result.details.isEmpty,
      clearResolvedRoute: result.resolvedRoute == null,
      clearPagination: result.pagination == null,
    );
    return true;
  }

  bool _isFeatureLoadCurrent(
    FeatureId feature,
    int generation,
    int lifecycleEpoch,
    int? ygdkGeneration,
  ) =>
      !_disposed &&
      lifecycleEpoch == _lifecycleEpoch &&
      generation == _featureRefreshGenerations[feature] &&
      (feature != FeatureId.ygdk || ygdkGeneration == _ygdkGeneration);
}
