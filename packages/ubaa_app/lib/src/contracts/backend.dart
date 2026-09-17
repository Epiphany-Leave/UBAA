import 'package:ubaa_domain/ubaa_domain.dart';

/// Core 当前认证状态的最小表示。
enum AuthStatus { signedOut, signedIn }

/// Bridge/Core 错误的安全边界。`detail` 只能记录脱敏诊断，不得传给 UI。
class BackendException implements Exception {
  const BackendException(
    this.code, {
    this.detail,
    this.kind,
    this.retryable,
    this.resolvedRoute,
    this.issueId,
  });

  /// 跨协调器兼容入口重新抛出时，不再把完整错误压缩成单个代码。
  factory BackendException.fromUi(UiError error) => BackendException(
    error.code,
    kind: error.kind,
    retryable: error.retryable,
    resolvedRoute: error.resolvedRoute,
    issueId: error.issueId,
    detail: safeReservationFailure(error.message),
  );

  final UbaaErrorCode code;
  final String? detail;
  final UbaaErrorKind? kind;
  final bool? retryable;
  final ConnectionMode? resolvedRoute;
  final String? issueId;

  @override
  String toString() => 'BackendException(${code.wireName})';
}

/// 只允许固定提示穿过 UI 边界，未知上游正文仍不展示。
String? safeReservationFailure(String? message) =>
    const {
      '课程选课资格缺少必要字段',
      '课程退选资格缺少必要字段',
      '课程当前不可选，请刷新课程详情后重试',
      '博雅预检响应缺少有效状态',
      '博雅预检响应缺少数据',
      '图书馆预约日期已变化，请刷新后重新准备',
      '图书馆预约时段已变化，请刷新后重新准备',
      '图书馆预约座位已变化，请刷新后重新准备',
      '图书馆座位预约资格缺少必要字段',
      '图书馆分区响应包含重复预约日期',
      '图书馆分区详情包含重复预约时段',
      '图书馆分区响应结构无效',
      '场馆预约日期响应与请求不一致',
      '场馆预约上下文缺少必要令牌',
      '图书馆业务会话已失效',
      '图书馆预约预检失败',
  '场馆预约预检失败',
  '场馆预约资格核对响应无效',
  '场馆预约资格已变化，请刷新后重新准备',
  '图书馆预约资格已变化，请刷新后重新准备',
    }.contains(message)
    ? message
    : null;

/// Flutter 宿主唯一需要依赖的业务接口。
///
/// 生产实现由 FRB 绑定适配；URL、Cookie、路由探测和会话文件均留在 Rust
/// Core 内部，Dart 层不拼接请求。
abstract interface class UbaaBackend {
  Future<AuthStatus> authStatus();

  Future<UserSummary?> userInfo();

  Future<void> prepareLogin(RoutePolicy policy);

  Future<void> login(LoginInput input);

  Future<void> logout();

  /// 首发只读功能统一返回摘要。详情 DTO 接入时保持此接口的错误语义。
  Future<FeatureResult> loadFeature(FeatureId feature);
}
