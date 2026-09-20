# 当前迁移与交付状态

2026-09-20 ui25：博雅详情/已选课程接入可选手机日历冲突检测、课程日程与预告选课提醒；时间转换和重叠判断经 Rust facade/bridge，Android 系统日历编辑页负责保存，iOS EventKit/EventKitUI 适配已编写。日历不上传、不落盘、不进入诊断；本科/研究生数据层不变。Pixel 8 待用户安装 `output/UBAA2-pixel8-boya-calendar-ui25.apk` 验证；iOS 尚未在 Mac/Xcode 编译或真机验证。检查结果与手动步骤见 [日历验收记录](evidence/2026-09-20-boya-calendar.md)。

ui22 构建交付：`output/UBAA2-pixel8-secure-storage-ui22.apk`，154432016 字节，Android x64 debug，应用名 UBAA。全量 `just check` 仍在 references shell 自测因 `/tmp` 与 Windows Temp 表达差异失败；日志 `output/secure-storage-ui22-check.log`。真实 Keystore 能力由运行时加解密探测，持久化行为由用户在 Pixel 8 上确认；其他平台安全存储不在此次范围。

2026-09-19 ui22：接通 Android Keystore 安全凭据存储，使用 AES-256-GCM、固定命名空间 AAD 与随机 IV，加密结果原子写入 noBackupFilesDir；只有用户选择记住密码/自动登录才保存。原生能力探测实际执行加解密回环，错误不泄漏凭据或降级明文。此能力仅为账号密码保险箱，不改变 Rust Core 的 Session/Cookie。按用户确认，“更新课表”改名“本地化课表”并同步说明、组件空态文字，首次自动导入保留。研讨室改为 UBAA-PR 高级功能入口的日历图标。17 项凭据/通道测试、64 项控制器测试、3 项课表 UI 测试通过，UI analyze、refs、敏感扫描和 diff 检查通过；真实 Android 保存/重开恢复/清除仍待 Pixel 8 验证。

2026-09-17 ui21 身份隔离加固：删除 Core 内部未知身份跨本科/GSMIS 重试、学期格式猜身份、空本科校历切研究生等历史回退；保留原 facade 身份门禁。现在内部学期、周次、今日课表、考试、成绩与整学期导入同样要求明确身份。研究生学号大小写均支持；未知/继续教育号码直接报错，零教务请求。已知身份即使接口失败也不跨系统；共用传输与按域 Cookie 基础设施不等于共用教务接口。Core lib 248 项、facade 21 项全通过，refs、敏感扫描、diff 检查通过。全量 `just check` 仍受 references shell 自测 Windows Temp 路径差异阻断。实际本科账号尚待用户验证，不能把自动化通过当成两类账号均已实测。

2026-09-17 ui20 / GitHub 保存点：按用户要求，将当前累计 GSMIS、本科/研究生分流、离线课表、桌面组件与界面迁移源码保存到 Epiphany-Leave/UBAA 的 `UBAA2` 分支。本地分支 `migration/UBAA2` 避免 Windows 与既有 `ubaa2` 大小写冲突。新增 Android 系统拍照/相册通道，接入现有打卡选图、预览与确认流程；不自动提交。平台适配 11 项测试、Platform analyze、敏感扫描、diff 检查和 Android x64 构建通过；实际相机/相册操作等待 Pixel 8 验证。APK 为本地 `output/UBAA2-pixel8-photo-ui20.apk`（154441759 字节）。`just check` 仍在 references shell 自测因 Windows Temp 与 `/tmp` 路径差异失败，实际 `just refs` 通过。此分支是可继续开发的保存点，不代表全平台或全部业务验收完成；个人数据、APK、日志、失败截图和本机配置不纳入提交。

ui19 交付：`output/UBAA2-pixel8-ygdk-reminder-ui19.apk`（154442232 字节，Android x64 debug，应用名 UBAA），等待 Pixel 8 验证。`just check` 在 references shell 自测因 Windows Temp 与 `/tmp` 路径表达差异失败，实际 `just refs` 通过；完整日志 `output/ygdk-reminder-ui19-check.log`。不声明自动完成判断或全量门禁已通过。

2026-09-17 ui19：下一项为阳光打卡首页提醒的手动开关增量。默认关闭，开启后显示常驻提醒和“前往阳光打卡”，可手动关闭；私有目录按账号保存开关，重启后恢复，不保存打卡内容或凭据。未复制上游固定 4/16 次阈值，自动按周/学期关闭和系统通知尚未迁移。本轮没有增加依赖、权限或后台查询。6 项测试覆盖提醒保存失败/恢复/跳转、按账号持久化，以及现有首页与成绩提示回归；UI/Platform/Host analyze、敏感扫描与 diff 检查通过。用户验证建议：开启 → 重新打开应用确认保留 → 点击打卡入口 → 关闭。

ui18 全量检查仍在 references shell 自测遇到 `/tmp` 与 Windows Temp 路径差异而失败，实际 `just refs` 通过；日志 `output/grade-notice-ui18-check.log`。APK 大小 154435617 字节。真实变化提示待非空成绩前后样本验证，未宣称跨重启监控完成。

2026-09-17 ui18：用户确认 ui17 成绩空统计正常，非空成绩仍待实际数据。本轮补首页“本次登录期间成绩变化”提示，可查看成绩或忽略。首次成功查询建立内存基线，后续正常默认刷新对同学期、同课程号、同路线的分数字符串变化提示；失败、无成绩、筛选查询、重复身份不造成误报，注销/重建快照清理基线。只协调已有 Core 读取后的界面提示，无额外联网、计时轮询、落盘或成绩计算。跨重启基线及系统通知未迁移。64 项控制器测试、2 项 UI 测试，App/UI/Host analyze、敏感扫描和 diff 检查通过。交付 Android x64 debug `output/UBAA2-pixel8-grade-notice-ui18.apk`，应用名 UBAA；暂无真实成绩时应当没有变化提示。

ui17 交付：`output/UBAA2-pixel8-grades-ui17.apk`，Android x64 debug，154434224 字节，应用名 UBAA。敏感扫描、diff 检查和构建通过；全量 `just check` 仍在 references shell 自测因 `/tmp` 与 Windows Temp 表达差异失败，日志 `output/grades-ui17-check.log`；实际冻结引用验证通过。没有提交或推送，等待 Pixel 8 验证。

2026-09-17 成绩卡片增量（ui17）：用户确认 ui16 关于页正常。本轮迁移成绩统计摘要及可点击的课程卡片，保留学分、绩点、文字成绩和空统计的原始展示值；折算分等完整字段在详情中显示且仍可本地搜索。只改 UI，未改变本科/研究生业务分流、请求、GPA 计算和缓存。专项测试先复现旧列表未折叠详情，再验证摘要、文字成绩、零学分、隐藏字段搜索和详情入口；成绩/阳光/关于页 3 项测试及 UI analyze 通过。真实非空研究生成绩仍待用户数据验证。

ui16 验证：关于页专项测试通过，UI/Host/Platform analyze、敏感扫描和 diff 检查通过。Platform 首次检查缺少本地 package 配置，使用现有缓存离线解析后通过，未保留自动解析产生的锁文件版本变更。Android x64 debug 构建成功，交付 `output/UBAA2-pixel8-about-ui16.apk`（154428165 字节），等待用户 Pixel 8 验证。`just check` 在 references shell 自测因 `/tmp` 与 Windows Temp 路径表达不一致而失败；真实 `just refs` 通过。完整日志 `output/about-ui16-check.log`，不声明全量门禁通过。

2026-09-17 关于页增量（ui16）：用户确认阳光历史子页面入口存在，因无打卡数据，非空记录继续待验证。本轮只补“我的 → 关于 UBAA”、Android 已安装包版本读取、外部项目主页（失败可复制地址）及 Flutter 原生许可页面。Android 使用原生 MethodChannel，无新依赖；其他平台暂显示版本不可用，项目地址仍可复制。新增行为测试先因缺少宿主回调失败，随后覆盖版本失败重试、地址回退和许可导航。学校业务、身份分流及缓存均不改动。

本轮交付：`output/UBAA2-pixel8-reservation-ui10.apk`（Android x64 debug，应用名 UBAA，供 Pixel 8 使用）。空教室、研讨室、博雅、图书馆专项 UI 4 项与 bindings schema 15 项通过；App/UI analyze、合同版本检查与 diff 检查通过。构建使用已有 Rust 1.95.0 Android target，Java 本次进程参数指定 `-Djdk.net.unixdomain.tmpdir=D:\Z_Program\UBAA\tools` 绕过默认临时路径的 loopback 失败，不修改系统配置。用户安装后按空教室→博雅准备→图书馆准备→研讨室三入口顺序验证；准备或确认失败需要记录具体功能、错误原因与错误编号，尚不能宣称全部真实预约问题已解决。

2026-09-14：Flutter bridge contract v12 增加 Core 已解析的研讨室密码展示字段。空教室固定显示选中楼栋，首栋默认对勾，删除重复楼栋标题。研讨室恢复三入口、筛选、时段选择、表单及预约详情。博雅详情空当前人数/可选选课窗口按旧版处理。Core 244 项与 bridge 112 项（另 2 个子进程入口跳过）通过，App 198 项通过，新增预约提示测试通过。全量 UI 仍有旧布局/截图与查询入口用例不匹配，不能称全量测试通过；`just check` 在冻结引用 shell 自测中因 Windows 与 /tmp 路径表达差异中断，实际 `just refs` 通过。真实图书馆、研讨室写入尚待验证。详见 [对照记录](evidence/2026-09-14-reservations.md)。

第五轮修正：SPOC、希冀、成绩和考试的本地搜索提升到页面固定层，加载、空数据、失败和有数据时均显示。图书馆按 UBAA-PR 原页面重新迁移：楼馆、楼层、分区使用横向筛选条，自动选择首个可用日期与时段并加载座位，只展示可预约座位；带入原项目 29 张分区平面图及缩放/平移/重置查看，预约摘要、确认预约、预约记录、刷新和取消交互与 UBAA-PR 保持一致。

第五轮界面验证：空教室课节表头改为纵向滚动时固定；SPOC、希冀、成绩和考试增加右下本地结果搜索，放大镜不发起服务器请求；普通功能卡片改为显示功能说明。图书馆座位复用已有 Core 能力改为 UBAA-PR 式“预约座位 / 我的预约”两入口，预约按楼馆、楼层、分区、日期、时段和座位逐级选择，我的预约支持刷新和取消。UI 专项 4 项、App bridge 28 项及两个 Flutter package analyze 通过；旧 widgets 全量测试仍因已知界面重构后的 golden 和旧控件交互断言未同步而失败。

更新日期：2026-09-13，Asia/Shanghai。

第四轮界面验证：按 UBAA-PR `ClassroomQueryScreen.kt` 独立实现空教室页面，保留学院路/沙河/杭州校区、日期选择、教室或楼栋本地搜索、楼栋筛选、空闲图例，以及一屏 1–14 节状态表。搜索和楼栋选择只过滤当前已加载结果，不发起请求；切换校区或日期才重新查询。共享详情页的右下放大镜也改为本地结果搜索，服务器查询移动到右上筛选面板内并明确标为“查询”。未新增依赖或修改 Core。空教室和查询语义 3 项专项测试、Flutter analyze、敏感扫描、diff 检查及 Android x64 debug 构建通过。交付 `output/UBAA2-pixel8-classroom-ui4.apk`，等待 Pixel 8 验证。

第三轮界面验证：用户指出课表缺少 XDYou 式可操作周缩略条，普通功能的筛选卡和实际路线占用空间。课表现增加横向可点击周卡，点阵概览每天/时段的课程分布，与 PageView 滑动和当前周选择同步；课表选项使用调节图标。普通功能复用同一个紧凑查询层：右上调节图标打开筛选底部面板，右下搜索悬浮按钮执行查询；详情页不再展示实际路线和重复返回按钮。实现复用现有 Flutter/查询状态，无新增依赖或 Core 修改。专项 3 项测试、Flutter analyze、敏感扫描、diff 检查及 Android x64 debug 构建通过。旧 widgets 测试中的 22 项查询操作仍依赖展开式旧控件，另有既有截图基线差异，需后续同步测试交互。交付 `output/UBAA2-pixel8-schedule-ui3.apk`，等待 Pixel 8 验证周卡和紧凑查询交互。

用户已确认首页布局及入口正常。第二轮 UI 精简课表页：移除重复的周次下拉框和左右按钮，保留滑动翻周、回到本周图标；学期选择、手动更新、缓存信息移入三点菜单，错误详情通过提示图标查看。参考 XDYou `content_classtable_page.dart` 的菜单布局，独立使用 Flutter 组件实现，未修改 Core。修复 Android 三种小组件共用周课表预览及空状态标题的问题，今日/近日组件提供独立预览并隐藏周次导航，无障碍描述对应实际日程。课表与首页 5 项测试、Flutter analyze、敏感扫描、diff 检查及 Android x64 debug 构建通过；完整检查仍受下述既有环境阻碍。交付 `output/UBAA2-pixel8-schedule-ui2.apk`，等待 Pixel 8 验证顶栏和小组件预览/实际展示。

首页 UI 第一轮：借鉴本地 XDYou 的“今日信息卡片 + 快捷入口”组织方式，独立使用现有 Flutter 组件实现。首页展示课程时间/地点、近期考试及四个快捷入口，完整功能目录保留在普通功能页；支持窄屏纵排和宽屏并排，保留缓存与错误提示。未复制 XDYou 源码、学校接口或 GPA 规则，未增加依赖。本轮不更改 Rust 协议。交互回归 91 项通过，敏感扫描通过，Android x64 debug 构建通过；完整截图测试仍存在旧基线差异和此前课表页返回按钮断言失配，未批量更新基线。`just check` 仍因 Bash 找不到 `just` 中断；`just refs` 仍被既有脏冻结目录阻断。交付 `output/UBAA2-pixel8-home-ui1.apk`，等待用户在 Pixel 8 验证首页布局与入口。

后续验收：用户确认 `UBAA2-pixel8-schedule-fix1.apk` 课表查询正常。本轮仅补全成绩总览和考试学期在本科空校历下的 GSMIS 分流，Core 单元测试 241 项通过（含本科路线保持、研究生空考试、空成绩统计）。成绩和考试实际查询仍待本轮 APK 的 Pixel 8 验证；非空研究生考试明细仍未适配。整体验证门禁的既有环境阻碍见下文。

本轮 Pixel 8 用户反馈：课表更新、成绩、考试未通过；博雅、空教室、图书馆座位、场馆预约、阳光打卡、教学评教可以使用；首页与功能页重复。按用户要求每轮只交付一个问题的 APK。本轮补全空本科校历的 GSMIS 整学期导入回退，新增测试先失败后通过，Core 单元测试 240 项通过，敏感信息扫描通过。`just check` 因 Bash 找不到 `just` 未执行完整门禁，`just refs` 因既有 `ubaa_old` 工作树不干净失败。真实课表恢复待本轮测试 APK 验证；界面、成绩、考试尚未在本轮修改。

## 当前活动阶段：UBAA-PR 功能迁移

当前活动合同见[功能迁移合同](../../goal.md)，产品级状态和工作顺序见[UBAA-PR 功能迁移矩阵](ubaa-pr-feature-parity.md)。研究生 GSMIS 适配是其中课表、成绩与考试的基础能力，不单独等同于全部功能迁移完成。

第一批为启动基线、已迁离线课表的 Pixel 8 验收，以及旧版 Android 桌面课表组件的迁移。其后按矩阵将仍为通用查询页的功能逐项改为专用交互页面。

## 进行中的基础阶段：研究生 GSMIS 适配

活动合同见[研究生适配](../../goal.md)。范围和顺序已确认；基线为上游 `ubaa2` `347eda209cda9f5a85804e8fffb93e84ab489188`。正在协议对照与实现，尚未验收。Android 使用 Pixel 8 模拟器。下文维护治理结果为历史记录，不代表本次适配已通过。

本轮本地检查、上游 Windows 基线问题和剩余验收见[研究生验证记录](evidence/2026-09-10-graduate-gsmis.md)。

正在迁移 UBAA-PR 周课表交互及按账号整学期离线缓存，来源与验证见[课表迁移](evidence/schedule-offline-parity.md)。Bridge contract 升至 v11，CLI schema 仍为 v11。

## 历史阶段：可维护性治理

该阶段合同已[归档](history/goal-2026-09-07-maintainability.md)，设计和实施计划分别见[设计](../superpowers/specs/2026-09-07-maintainability-design.md)与[计划](../superpowers/plans/2026-09-07-maintainability.md)。该阶段处理错误传播、本地安全诊断、传输诊断、严格门禁和可共享交接证据。

本轮本地可维护性治理已完成，最终实现内容为 `541981ea51a79044043b74cec3af0a32b5c35308`，详见[验收记录](evidence/2026-09-07-maintainability.md)。真实 App 与 Core-live 保持暂停。本轮不读取 `.env.local`、会话或实时响应，不执行真实学校写入、签名发布、设备安装或诊断上传。

## 已确认的合同与历史事实

| 项目 | 当前事实 | 边界 |
|---|---|---|
| 冻结引用 | `ubaa_old` `6e75e120a26b0eefb3ab4a6f8251d1230db4a62e`；`examples/buaa-api` `efb7976bf513f38364b88aeb83d704586cff9b2a` | 认证和只读行为变更仍须逐操作来源对照。 |
| 当前适配合同（待验收） | CLI JSON schema v11；Flutter bridge contract v11；`session.json` v2；`config.toml` v1 | 研究生总览、考试学期、课表时间轴与离线课表显式升级公开合同；不得静默变更。 |
| 历史源码验收 | `0bd866c9ff5f205f2b1604bf5e72640a3e735018` | 这是 2026-09-05 的历史 verified 源码 SHA；摘要在[仓库内证据](evidence/2026-09-05-code-organization-summary.md)，本轮未重新在线核验。 |
| macOS 历史修复 | `cf5d431338d22d18c0e24245bb0ad1fd16709dde` 补齐 DebugProfile/Release 的主动联网权限 | 来源为归档合同；基础登录有用户确认，完整真实 App 验收仍暂停。 |

历史源码 SHA 与证据记录必须分开解释：`0bd866c9` 是 2026-09-05 验收报告对应的源码；该报告的脱敏内容被本仓库摘要引用，不把随后任何文档提交写成已重新验证的源码候选。

## 本轮已验证

- 错误字段完整传播、单一展示模板、结果未知禁止通用重试；有界本地诊断可从登录失败页与个人页主动查看/复制。
- Reqwest 真实回环、保守失败分类与 Bridge 安全 DEBUG 日志接线；CLI 默认 JSON stderr 合同保持。
- `just check-strict` 通过，实际运行 ShellCheck 0.11.0；CLI 128 项、Bridge 110 项、Flutter 396 项、维护 Shell 16 项及版本 Shell 7 项通过。
- FRB 重生成零漂移、macOS 脱敏宿主 integration 7 项通过；macOS 生产 Debug、Android 四种架构 APK、iOS simulator、OHOS API26 无签名 HAP 与本地产物检查通过。
- 结构门禁零例外、敏感扫描通过，独立复审无未解决高、中风险问题。源码验证内容和后续文档记录分别记账。

本轮未推送，未运行远端 CI，也未重验 Windows/Linux 原生运行器。历史 CI 成功不能继承。

## 真实产品验收仍未完成

- macOS 真实 App 的 Direct/WebVPN、会话恢复、用户中心和十二领域读取矩阵。
- 真实业务写入及写后读取核对。
- 正式签名、公证、商店上传、实体设备安装、原生安全存储和设备权限。

Fixture、Mock、golden、无签名构建、宿主集成、历史 Core-live 和历史 CI 各自只证明其记录范围，不能替代以上真实产品验收。

## 历史归档

- [2026-09-07 维护治理前状态全文](history/status-2026-09-07-before-maintainability.md)
- [2026-09-07 macOS 真实 App 活动合同全文](history/goal-2026-09-07-macos-real-app.md)
- [2026-09-02 及以前状态流水](history/status-through-2026-09-02.md)

归档保留当时的失败、修复、用户确认、暂停和计数，不以历史成功覆盖当前候选或本轮未执行项。
# 2026-09-15 图书馆取消入口修复

最终验证：Core 单元测试 245、图书馆接口测试 25 均通过，Android x86_64 debug 构建成功，已保存 output/UBAA2-pixel8-libbook-cancel-ui11.apk。使用已有工具 PATH 重跑完整 check 后，仍在 references shell 测试的 Windows /tmp 与 C:/Users 路径比较处失败；完整门禁未通过。没有自动取消真实预约。

用户确认 ui10 图书馆座位预约成功，截图中的“预约成功”记录缺少取消按钮。本次 Core 补充精确成功名称的资格回退，6/8 与已终止名称仍拒绝，空目标和未知状态仍不放行；列表与取消前复核共用解析器。回归先失败后通过，Core 单元测试 245 项通过，敏感扫描 940 文件通过。完整 check 被 Bash 中 just 不在 PATH 阻断；未安装工具或更改系统配置。测试 APK 计划为 output/UBAA2-pixel8-libbook-cancel-ui11.apk，真实取消由用户确认验证。
# 2026-09-15 学业身份和课表缓存修复

本轮测试包：`output/UBAA2-pixel8-academic-identity12.apk`，Android x86_64 debug，应用名 UBAA，仅供 Pixel 8 模拟器。Core 以官方用户资料学号分类本科/研究生；学业 facade 统一检查，未知格式拒绝自动教务查询。重启恢复身份，登出清除身份；已知身份不会因失败改用另一系统。周课表 code 不再作为学期校验；合法日期时间可缓存并规范为日期；首次进入无缓存的周课表自动导入，首页和已有缓存仍离线读取。

验证：Core 248 项单元测试通过；facade 原有 20 项通过，新增会话恢复/未知身份专项通过；Flutter App 课表 2 项及 UI 课表 3 项通过；App/UI analyze 与 sensitive scan 通过。Android 构建成功。全量 check 受 Windows/MSYS 冻结引用路径差异阻断，refs 另报告 ubaa_old 已有修改；全量 Core 集成运行发现博雅写权限测试失败，未在本轮改动该业务。Clippy 也存在其他模块既有告警，不能宣称全量门禁通过。尚待用户分别以研究生和本科账号验证；未执行真实业务写入、安装或系统配置修改。
# 2026-09-15 小步迁移 13

`output/UBAA2-pixel8-map-case13.apk`：研究生学号识别支持大小写和混合大小写；上游地图交互增强（放大/缩小、触控板缩放、静态图说明）。地图原本已存在，此次不重复迁移资源或预约业务。分类、恢复会话和地图按钮专项测试通过，UI analyze、refs 通过；Pixel 8 安装验证由用户执行。未重跑此前受环境/其他业务问题影响的全量门禁。
# 2026-09-16 小步迁移 14

Android x86_64 debug 构建通过，已生成 exam-ui14.apk。UI analyze、敏感信息与 diff 检查通过；refs 报告 ubaa_old 未提交修改，全量 check 失败日志保存在 output/exam-ui14-check.log。没有安装、发布或改动系统配置。

用户确认 map-case13 验证成功。本轮继续迁移上游考试展示：本地已安排/未安排分组和日期排序保留，增加时间线、紧凑的时间/地点/座位卡片、点击完整详情；搜索继续覆盖隐藏在详情中的字段。保留完整日期以避免跨学期歧义，不根据 Dart 推断考试结束状态。数据协议、研究生适配、Core/Bridge 均不改动。目标包 `output/UBAA2-pixel8-exam-ui14.apk`。专项 UI 测试通过；同文件既有博雅搜索测试因找不到入口失败，本轮未修改博雅页面。
# 2026-09-16 小步迁移 15

Android x86_64 debug 构建与敏感信息/diff 检查通过，ui15 APK 已生成。全量 check 日志为 output/ygdk-ui15-check.log；全量结果未通过，不等同于专项测试成功。

本轮 `output/UBAA2-pixel8-ygdk-ui15.apk`：阳光打卡概览展示官方学期认定次数和可选本周统计；新增概览/历史记录快捷入口，历史紧凑卡片点击展示完整资料。保留通用搜索、服务端分页及原有项目打卡入口。记录详情补齐 Bridge 已有的项目编号、状态编号；不推测编号业务含义。未引入新协议、依赖或系统权限。

验证：新增阳光页面测试、4 项 App 阳光映射测试通过，App/UI analyze 通过。扩展 UI 阳光回归 3 通过、9 失败，涉及照片预览、表单及旧筛选入口断言，未作为本轮已通过证据。refs 报告 ubaa_old 未提交修改；真实账号验证仍由用户完成。
# 2026-09-19 桌面组件与设置

按用户截图实现今日课程、近日课程、一周课程、日视图；后两种有每个组件独立的显示学期与样式设置。新增“我的→界面与课表设置”，持久化模式、颜色、字号、时间轴、周末、周次缩略图与行高。详见 [实现记录](evidence/2026-09-19-widgets-settings.md)。本轮基于 migration/UBAA2 当前源码，保留之前已完成的照片、身份、安全存储等修复，未修改 Core 业务。

# 2026-09-20 日历验收与 CI 修复

用户确认 ui25 在 Pixel 8 轻度测试通过。最新日历、组件和外观设置上传至个人 Fork 的 `UBAA2` 分支；旧测试及门禁修复情况以 [CI 修复记录](evidence/2026-09-20-ci-repair.md) 为准，取代此前记录中的相应已知失败项。iOS 仍需 Mac/Xcode 和 iPhone 原生验收。

# 2026-09-20 应用语言

ui26 新增“我的 → 语言”：跟随系统、简体中文、繁體中文、English，即时切换并保存。共享 Flutter 文案和系统控件本地化，学校数据保留原文；学校协议及本科/研究生分流不变。Pixel 8 APK 已生成，待用户手动验证。测试结果及本机完整门禁限制见 [语言实现记录](evidence/2026-09-20-language.md)。
