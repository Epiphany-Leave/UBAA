import 'timetable.dart';
import 'package:meta/meta.dart';

import '../common/error.dart';
import '../common/route.dart';
import '../write/actions.dart';
import 'catalog.dart';

enum FeatureLoadStatus { idle, loading, success, empty, stale, failure }

enum SigninDisplayStatus { pending, signed, late, unknown }

/// Unfiltered presentation of one queried day; never grants write permission.
@immutable
class SigninDaySummary {
  const SigninDaySummary({required this.date, required this.courses});
  final DateTime date;
  final List<SigninDisplayStatus> courses;
}

@immutable
class FeatureSnapshot {
  const FeatureSnapshot({
    required this.feature,
    this.status = FeatureLoadStatus.idle,
    this.summary,
    this.details = const <FeatureDetail>[],
    this.error,
    this.resolvedRoute,
    this.pagination,
    this.updatedAt,
    this.scheduleNavigation,
    this.timetable,
    this.signinDays = const [],
  });

  final FeatureId feature;
  final FeatureLoadStatus status;
  final String? summary;
  final List<FeatureDetail> details;
  final UiError? error;

  /// Core 对本次读取实际解析出的路线；不能用配置策略替代。
  final ConnectionMode? resolvedRoute;

  /// Core 返回的服务端分页元数据；只对支持分页的 typed 查询存在。
  final FeaturePagination? pagination;
  final DateTime? updatedAt;
  final ScheduleNavigation? scheduleNavigation;
  final Timetable? timetable;
  final List<SigninDaySummary> signinDays;

  FeatureSnapshot copyWith({
    FeatureLoadStatus? status,
    String? summary,
    List<FeatureDetail>? details,
    UiError? error,
    ConnectionMode? resolvedRoute,
    FeaturePagination? pagination,
    DateTime? updatedAt,
    bool clearError = false,
    bool clearSummary = false,
    bool clearDetails = false,
    bool clearResolvedRoute = false,
    bool clearPagination = false,
    ScheduleNavigation? scheduleNavigation,
    Timetable? timetable,
    bool clearTimetable = false,
    List<SigninDaySummary>? signinDays,
  }) => FeatureSnapshot(
    feature: feature,
    status: status ?? this.status,
    summary: clearSummary ? null : (summary ?? this.summary),
    details: clearDetails ? const <FeatureDetail>[] : (details ?? this.details),
    error: clearError ? null : (error ?? this.error),
    resolvedRoute: clearResolvedRoute
        ? null
        : (resolvedRoute ?? this.resolvedRoute),
    pagination: clearPagination ? null : (pagination ?? this.pagination),
    updatedAt: updatedAt ?? this.updatedAt,
    scheduleNavigation: scheduleNavigation ?? this.scheduleNavigation,
    timetable: clearTimetable ? null : (timetable ?? this.timetable),
    signinDays: signinDays ?? this.signinDays,
  );
}

/// 服务端分页的稳定展示元数据。页码按用户可见的 1-based 语义表达。
@immutable
class FeaturePagination {
  const FeaturePagination({
    required this.page,
    required this.size,
    required this.total,
    this.totalPages,
    this.hasMore,
  });

  final int page;
  final int size;
  final int total;
  final int? totalPages;
  final bool? hasMore;

  int get effectiveTotalPages {
    if (totalPages case final value? when value > 0) return value;
    if (size <= 0 || total <= 0) return 0;
    return (total + size - 1) ~/ size;
  }
}

/// 首页加载结果。每个功能独立返回，避免单个上游故障遮蔽其他卡片。
@immutable
class FeatureResult {
  const FeatureResult.success({
    this.signinDays = const [],
    this.savedAt,
    this.summary,
    this.details = const <FeatureDetail>[],
    this.resolvedRoute,
    this.pagination,
    this.scheduleNavigation,
    this.timetable,
  }) : isEmpty = false,
       error = null;

  const FeatureResult.empty({
    this.signinDays = const [],
    this.savedAt,
    this.resolvedRoute,
    this.pagination,
    this.scheduleNavigation,
    this.timetable,
  }) : summary = null,
       details = const <FeatureDetail>[],
       isEmpty = true,
       error = null;

  const FeatureResult.failure(this.error)
    : signinDays = const [],
      savedAt = null,
      summary = null,
      details = const <FeatureDetail>[],
      resolvedRoute = null,
      pagination = null,
      scheduleNavigation = null,
      timetable = null,
      isEmpty = false;

  final DateTime? savedAt;
  final List<SigninDaySummary> signinDays;
  final String? summary;
  final List<FeatureDetail> details;

  /// Core 对本次读取实际解析出的路线；失败或未执行时可以为空。
  final ConnectionMode? resolvedRoute;
  final FeaturePagination? pagination;
  final bool isEmpty;
  final UiError? error;
  final ScheduleNavigation? scheduleNavigation;
  final Timetable? timetable;
}

@immutable
class ScheduleNavigation {
  const ScheduleNavigation({
    required this.terms,
    required this.weeks,
    required this.term,
    required this.week,
  });
  final Map<String, String> terms;
  final Map<int, String> weeks;
  final String term;
  final int week;
}

/// 只读详情页使用的稳定展示模型，不携带原始上游载荷。
@immutable
class FeatureDetail {
  const FeatureDetail({
    required this.title,
    this.subtitle,
    this.fields = const <FeatureField>[],
    this.actions = const <FeatureAction>[],
  });

  final String title;
  final String? subtitle;
  final List<FeatureField> fields;
  final List<FeatureAction> actions;

  /// 返回该详情中首个与 [T] 匹配的 typed action。
  ///
  /// 缺失时返回 `null`，由消费端按不可操作处理。
  T? action<T extends FeatureAction>() {
    for (final action in actions) {
      if (action is T) return action;
    }
    return null;
  }
}

/// 详情卡片中的标签和值；值必须来自 bridge 白名单 DTO。
@immutable
class FeatureField {
  const FeatureField({required this.label, required this.value});

  final String label;
  final String value;
}
