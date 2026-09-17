# 课表交互与离线迁移

用户要求以 UBAA-PR 课表设计为准。参照其 ScheduleScreen、ScheduleViewModel、ScheduleRepository、SavedScheduleWeek：整学期完整后替换、按账号保存、今日本地派生、学期与周选择、连续分页、完整节次、点击详情、注销停用离线入口。

冻结 ubaa_old 的 LocalScheduleApi/DTO/测试提供本科既有接口；冻结 examples/buaa-api 不提供本次 GSMIS 离线仓库。现有 GSMIS 请求、CAS、重定向、Cookie、参数、编码、DTO 校验保持不变，协议对照沿用 source-parity.md。仅新增组合整学期读取与持久化：研究生一次学期响应派生全部周，本科复用现有学期/周/周课表方法；任一请求或验证失败不替换已保存学期。不借用本科协议推测研究生字段。

本地缓存只保存课表 DTO，不包含凭据。以成功登录账号为所有者，登录切换先停用旧账号，注销停用；失去网络或会话过期不把离线访问当成在线授权。UI 只从 Core 接收已解析数据。

## 本地验证（2026-09-10）

- Core 缓存测试先红后绿；覆盖完整学期替换、失败保留、账号隔离、同账号离线登录失败保留缓存及注销停用。研究生整学期导入测试确认只读取一次课程响应，包含无课程周和完整时间轴。
- Rust workspace 测试通过（2 项显式忽略）；返工后再次全量通过，其中 Core 239+22+8 项及 1 项文档测试通过。workspace clippy、rustfmt 通过。
- Flutter app 196、domain 25、host 21、bindings schema 14 项通过；周课表 2 项及既有查询控件 2 项通过。覆盖半拖动时两周可见、空周最后节次、跨学期本周、重叠课程、更新失败保留和空缓存替换。app/UI/host 静态分析通过。
- `just refs`、结构检查、敏感扫描通过。`just check` 仍停在既有 Windows references.sh 临时路径比较问题（`/tmp` 对 `C:/Users/.../Temp`），因此不声明总门禁通过；此前 golden 的 Windows 基线差异未在本次更新基准图。
- Android x86_64 debug APK 构建通过；已覆盖安装并启动 Pixel 8（API 36、16KB）。应用数据保留。实际学校课表内容、断网重启浏览等待用户验证，Mock/UI 测试不能代替此项。

## 审核返工

reviewer 提出的两项问题已在一次返工后关闭：本科原始响应没有 sectionTimes 时，参照 UBAA-PR 通用分支至少生成 1..12 节，唯一已知课程边界作为时间，未知或冲突保持空白，不套用研究生作息；真实本科 fixture（未增加人工字段）及空周/序列化测试先红后绿。课程仅在重叠连通组内分列，远离冲突的课程占满日列；布局回归先红后绿。独立复核未发现新的 P1/P2。
