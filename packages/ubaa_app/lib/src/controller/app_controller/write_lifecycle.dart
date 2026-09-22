part of '../app_controller.dart';

extension _AppControllerWriteLifecycle on AppController {
  WriteCoordinator _createWriteCoordinator(UbaaBackend backend) =>
      WriteCoordinator(
        diagnostics: _diagnostics,
        canStart: () => !_disposed && _writeTransitions == 0,
        // 闭包固定创建时的 backend，晚到 prepare 只能在原实例释放意图。
        commit: (intentId) => _commitWriteWithBackend(backend, intentId),
        discard: (intentId) => _discardWriteWithBackend(backend, intentId),
        receiptVerifier: WriteReceiptVerifier(
          refreshAfterWrite: (operation, query) =>
              refreshAfterWrite(operation, query),
          verifyCgyyReceipt: matchesCgyyReceipt,
          verifyCgyyCancellation: verifyCgyyCancellation,
          refreshYgdkAfterWrite: refreshYgdkAfterWrite,
          refreshEvaluationAfterWrite: refreshEvaluationAfterWrite,
        ),
      );

  void _beginWriteTransition() {
    // 必须先禁止入口，再发出 invalidate 通知，覆盖监听器同步重入。
    _writeTransitions++;
    _lifecycleEpoch++;
    _ygdkGeneration++;
    // Invalidated reads cannot publish a result, so settle their spinners now.
    for (final entry in _snapshots.entries.toList()) {
      if (entry.value.status != FeatureLoadStatus.loading) continue;
      _snapshots[entry.key] = entry.value.copyWith(
        status: entry.value.updatedAt == null
            ? FeatureLoadStatus.failure
            : FeatureLoadStatus.stale,
        error: const UiError(
          code: UbaaErrorCode.operationConflict,
          title: '查询已中断',
          message: '连接或账号状态已变化，请重试。',
          retryable: true,
        ),
      );
    }
    _writeCoordinator.invalidate();
  }

  void _endWriteTransition() {
    _writeTransitions--;
  }

  void _replaceWriteCoordinator(UbaaBackend backend) {
    _writeCoordinator.removeListener(_notify);
    _writeCoordinator.dispose();
    _writeCoordinator = _createWriteCoordinator(backend);
    _writeCoordinator.addListener(_notify);
  }

  Future<WriteCommitResult> _commitWriteWithBackend(
    UbaaBackend backend,
    String intentId,
  ) async {
    if (backend is! WriteCommitBackend) {
      throw const BackendException(UbaaErrorCode.unsupported);
    }
    if (intentId.trim().isEmpty) {
      throw const BackendException(UbaaErrorCode.invalidInput);
    }
    return (backend as WriteCommitBackend).commitWrite(intentId);
  }

  Future<void> _discardWriteWithBackend(
    UbaaBackend backend,
    String intentId,
  ) async {
    if (backend is! WriteCommitBackend) {
      throw const BackendException(UbaaErrorCode.unsupported);
    }
    final normalized = intentId.trim();
    if (normalized.isEmpty) {
      throw const BackendException(UbaaErrorCode.invalidInput);
    }
    return (backend as WriteCommitBackend).discardWriteIntent(normalized);
  }
}
