# 预约页面与旧版缺省字段对照

## 2026-09-15 图书馆取消入口

用户确认预约成功；截图显示“预约成功”记录没有取消入口、“用户取消”记录仍正常展示。冻结 Kotlin 与 UBAA-PR `LibBook.kt` 的 cancelBlockedMessage 只阻止空 ID、6/8 和终止状态名称，并非只允许状态 1；Rust 示例没有同协议图书馆模块。Core 原来只允许状态 1，导致其他状态配合明确成功名称时取消资格 Unknown。仅补充截图确认的精确名称“预约成功”，不推断它对应的数字码；6/8 仍优先拒绝，无 ID、其他未知状态仍 Unknown。取消状态名称采用旧版明确终止名称。列表与 prepare/commit 重新核对共用解析器，保留目标唯一性、分页及确认流程。

本次不改变 CAS/bootstrap、redirect/final URL、Cookie/session、HTTP 方法与参数、headers/编码、加密、缓存或错误策略：继续使用现有 Core 图书馆列表及 `/v4/space/cancel` JSON id 流程，Dart 只消费 typed eligibility。脱敏回归先得到 Unknown/Allowed 失败，再验证读取与严格取消核对均保留目标；截图没有提供原始状态码，完整真实取消仍待用户确认。本轮 refs 校验报告工作树不干净，但原生 git status 未列出改动；没有修改冻结目录。

本轮按用户要求恢复研讨室预约、我的预约、查看密码。真实写入由用户在 Pixel 8 上确认；自动验证不提交真实预约。

## 博雅详情选课资格

冻结 `ubaa_old/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalBykcApi.kt` 将选课起止时间、当前人数声明为可空；最大人数和开课时间仍必需。UBAA-PR 的 `BykcTimeFormatters.kt` 只在可选时间存在时检查选课窗口，并在人数存在时检查满员。
冻结 `examples/buaa-api/src/api/boya/data.rs` 的 Capacity 明确记载单课详情 current 为 null，需要默认处理；其 Schedule 要求时间，故可选时间行为采用冻结 Kotlin 与 UBAA-PR 的已有实现，不由 Rust 示例推断。
请求仍为 `queryCourseById` + `id`、`choseCourse` + `courseId` 的原有 Core 实现；CAS、重定向、Cookie、加密、headers、HTTP 方法和缓存策略无改动。补齐的是解析后资格判断的缺省行为；格式损坏、无开课时间、无最大人数仍不能签发 Allowed。
用户诊断记录存在 writePrepare 与 writeCommit 的 upstream_changed。这只能确认失败类别，不能把全部预约失败归为同一原因；空人数修复有源码和回归测试证据，仍待真实服务验证。

## 门锁密码

冻结 Kotlin LocalCgyyApi 和 UBAA-PR 都 GET `/api/orders/lock/code`，无额外查询参数，沿现有 cgyy 认证和 Cookie 作用域；响应 code=200 的 data 由旧版 UI 读取。UBAA-PR `CgyyLockCodeScreen.kt` 使用 qrCode、dueDate、orderView 的 venueName/siteName/venueSpaceName/reservationDateDetail；冻结及现有测试另有 password/lockCode 字段。
Rust 示例没有同一研讨室协议，不能借用其他功能字段。Core 只提取这些已确认字段，经 typed bridge 显式展示，普通 CLI 序列化与 Core Debug 仍不输出密码，不向 Dart 传原始 JSON。空 data 保持无密码语义，认证错误和非成功信封仍报错；页面离开即移除展示，不增加磁盘缓存。

## 页面

按 UBAA-PR CgyyHomeScreen、CgyyReservePickerScreen、CgyyReserveFormScreen 组织三入口、固定筛选区域、选择同一研讨室最多两个相邻时段、活动类型选项和预约详情。所有查询/提交仍使用既有 bridge/facade；页面不构造上游 URL 或凭据。
