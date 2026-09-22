# 本地缓存与签到日期 / 时间门槛

冻结引用已通过 refs 校验：ubaa_old 6e75e120；buaa-api efb7976。此轮只在 Pixel 8 验证，不交付 ARM64。

## 协议对照

- `ubaa_old/shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalSigninApi.kt`：GET 8347 `app/course/get_stu_course_sched.action`，参数 id/dateStr（YYYYMMDD），sessionId 头；响应 STATUS/result 及 id/courseName/classBeginTime/classEndTime/signStatus。日期原来固定今天。
- `examples/buaa-api/src/api/class/opt.rs` 的 query_schedule 接受任意日期，沿用同一路径与 YYYYMMDD dateStr。class/core.rs 和 data.rs 管理业务会话与 8346 登录、8347 查询。不是教务身份推断依据。
- 当前 Core 已有 CAS 入口、重定向限制、sessionId 业务登录及解析。此轮日期查询只替换 dateStr，不修改学校认证、Cookie/Session 作用域、用户参数、加密或重定向规则。非成功响应保留失败，不能沿袭旧 Kotlin 将异常变空列表的行为。
- 签到写入：两参考均指向直连 HTTP 8081、WebVPN 8347，对学校服务器时间戳及 courseSchedId 进行提交；Core 当前将直连也写到 HTTPS 8347，需要按已冻结参考修正。WebVPN 保留当前已验证的安全外层 URL。保持显式确认、资格复核、发送后不自动重试及未知结果语义。
- 开课前十分钟为本次用户要求的本地限制，并非推断学校授权。按北京时间判断，缺失或无效时间关闭入口；结束后关闭。日期查询保留原始签到状态，动作是否开放另行计算。提交前重新查询今天的服务器状态及时间窗口。
- 课表补充项来源为已验证账号的本地课表，不拿教务课程编号冒充 iClass courseSchedId；无服务器签到标识仅供查看。

## 缓存边界

### 第二轮反馈修正

用户报告教师造成相同展示 ID 的重复行。再次对照：旧 Kotlin `mapSigninClass` 将 `id` 映射到 courseId；buaa-api `Schedule.id` 明确用于签到，而独立 `courseId` 仅查询课程安排。因此只按非空的安排 ID 合并，不按课程名或教学课程 ID 合并；相同 ID 的名称、时间或状态冲突时保留一条但关闭写入目标。读解析和写前查询共用规则。认证、线路、Cookie、请求参数和写入格式保持上轮已核对行为。

整周查询复用相同日期 GET 七次，按账号/周一日期存储原始已解析的签到展示快照；七天全部成功才原子替换。缓存可用于展示准备入口，但写前资格仍重新向学校查询。每次读取重新计算北京时间窗口和未来日期，不将缓存时间当成当前时间。本轮修复日期条/筛选重叠，点阵固定四列三行。

第二轮验证：一致教师重复行的提交测试先失败，修复后通过；Core 单元 251 项、签到集成 13 项、bridge 签到 6 项、CLI 合同 96 项、Flutter App 202 项、Host 21 项和 UI 专项 6 项通过。覆盖整周七次读取无写请求、磁盘快照重新打开/同周换日、未来状态、重复安排只写一次、状态冲突阻止写入、窄屏筛选不重叠、点阵四列三行及刷新标志。App/UI analyze、workspace Clippy、layout、敏感扫描和 diff 检查通过；完整 `just check` 仍因缺少 `zip` 中止。

已生成并覆盖安装 `output/pixel8/UBAA2-pixel8-signin-week-cache-test.apk`（x86_64 Debug、INTERNET 权限存在），启动成功，等待用户验证整周真实数据和重复课程卡。未提交真实签到，未构建 ARM64。空签到 ID 不合并；同名不同 ID 不合并；超过 12 门仅压缩点阵，课程总数与下方完整列表不截断。

复用 Core 的私有文件、锁、原子替换和账号选择生命周期，新增已解析只读 DTO 快照。课表沿用现有缓存。成绩、考试、学期和作业清单首次加载后保存；缓存命中不执行学校请求，手动刷新失败保留旧快照，成功空结果覆盖旧值。不缓存密码、Cookie、业务 Session 或写入资格。本科/研究生由当前账号隔离且原网络读取保留身份门禁；不新增跨身份回退。CLI 原读取 API 维持在线语义。

## 验证和交付

- Rust workspace lib：Core 250、CLI 13、bridge 112 项通过（2 个子进程入口跳过）；签到集成 11 项通过，包含指定日期、无效日期无请求、窗口外不获取时间戳/不提交。
- Flutter App 202、Host 21 项通过；UI 专项 4 项通过，覆盖日期卡点击/换周、未筛选的日统计、课表课程数、四色显示和系统返回；App/UI analyze 通过。
- layout、refs、敏感扫描和 diff 检查通过。`just check` 在 maintenance-gates shell 自测遇到本机缺少 `zip` 中止，不宣称完整门禁通过，未安装新工具。
- workspace Clippy 全目标/全特性通过，CLI JSON/命令合同 96 项通过。缓存结果使用独立 `CachedRead` 包装，不改变原 live `Routed` 合同；CLI 继续使用原有实时方法。
- 用户确认首版 `output/pixel8/UBAA2-pixel8-cache-signin-test.apk` 重启缓存/手动刷新可用，签到日期与时间门槛可用。
- 按用户反馈追加顶部周日期卡，课程数来自本地课表，查询后的红/绿状态来自学校原始签到状态；未查询/未知为灰色，不将无记录视作未签到。展示层预留黄色迟到，但两份冻结来源尚未证明迟到编码，不能将其他数值猜为迟到。已查询的概览仅保留在当前页面内存，提交前始终重新校验。
- 第二版 `output/pixel8/UBAA2-pixel8-cache-signin-overview-test.apk` 已构建并覆盖安装 Pixel 8，成品为 x86_64 且包含 INTERNET 权限，应用启动正常；日期概览待用户确认。本轮不构建 ARM64。

冷启动仍需现有会话校验，本轮不是离线登录。实时预约余量、签到资格及写入前确认不使用持久快照。真实签到写操作由用户在真实上课窗口手动验证，自动测试不能代替业务成功。
