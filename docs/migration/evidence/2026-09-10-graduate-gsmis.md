# 研究生 GSMIS 适配验证记录

日期：2026-09-10。状态：本地验证与独立审核中，未完成 Android/真实上游验收。

## 来源与范围

开发基线：上游 `ubaa2` 的 `347eda209cda9f5a85804e8fffb93e84ab489188`。研究生补充来源为旧 UBAA-PR 的 `fdd85993b807e7a3977cbae5fe279d15f52f1c75` 及当日 17 个 Kotlin 工作区覆盖文件（含未提交内容），已在仓库外保留源码快照和 SHA256 清单。两份冻结来源已按 `references.md` 建立并通过只读校验；逐操作协议对照见 [source-parity](../source-parity.md)。

范围包括 GSMIS 正式课表与节次时间、独立考试学期、空考试、完整成绩分页和独立研究生 GPA，以及 CLI/Flutter 消费。非空考试明细缺少证据，明确不宣称已适配。非空成绩使用合成数据测试，不能替代真实账号验证。

## 已执行检查

- 主线程使用锁定依赖和离线模式复验 Core：413 通过、0 失败、0 忽略（232 单元、180 集成、1 文档）。实现阶段保留先失败后通过的研究生行为测试；Core 严格 clippy 已通过。
- CLI 实现阶段全部测试通过，其中合同测试 96 项；生成绑定后的工作区集成复验另行记录。
- FRB 2.13.0 实际生成绑定；再次离线生成前后，全部 Rust/Dart 生成文件 SHA256 完全一致。
- Flutter bindings 16/16、app 191/191 通过；UI 93 通过、3 个视觉基线测试组失败。三包 analyze 零问题。
- CLI v11 / Bridge v10 合同一致性检查通过；敏感信息扫描通过（896 个仓库文件，未将测试截图纳入提交）。

## 已确认的基线环境问题

在同机、同 SDK、未修改的上游基线工作树重新执行三个失败的视觉测试组，全部复现。当前与基线的 15 张实际渲染图片逐 SHA256 比较完全相同。例如主页均为 1.17% / 11979 像素差异，响应式手机主页均为 2.11% / 6935 像素差异。未覆盖 golden 图片。

`just check` 已执行：布局脚本合同 40 项、版本脚本合同 7 项通过，随后停在未修改的 `scripts/tests/references.sh`：Git Bash 临时路径 `/tmp/...` 与 Windows Git 记录的 `C:/...` 远端路径不匹配。同一检查在上游基线也失败，因此不能将 `just check` 记为通过。ShellCheck 未安装，普通入口明确报告跳过。

## 尚未完成

- 审核指出的五项问题已修正：登录失效不再触发 GSMIS 后备、后备失败保留原错误分类、非空考试明确返回暂不支持、今日课程只读取当前学期、非法节次不再被静默丢弃。恢复工作时补齐 Rust/Dart 的 Unsupported 穷尽映射。
- 修正后 `cargo test --locked --offline --workspace --quiet` 全部通过（2 项忽略）；原登录失效清理会话回归通过。Flutter app 193 项通过，analyze 零问题。
- 用户授权后已安装 NDK 28.2.13676358，并构建 x86_64 debug APK、核验其中包含 Rust 动态库、安装启动于现有 Pixel 8（Android 16，16KB）。未重置模拟器。
- Android 启动验证发现并修复应用私有目录缺失和 Rust 1.95 标准文件锁不支持问题；Android 使用获准新增的 fs2 保留文件锁。更新安装后登录页初始化正常，不再显示 unsupported；学校登录及查询待用户操作验证。
- 本机构建使用 RUSTUP_TOOLCHAIN=1.95.0 和 JVM 参数 -Djdk.net.unixdomain.tmpdir=D:\Z_Program\UBAA\tools\java-temp。Cargokit 修复固定版本/CRLF 工具链识别、尊重工具链环境变量和 Flutter 目标架构，以及 Windows 错误退出码传递。
- 本轮没有真实 Direct/WebVPN 请求、实体手机测试、学校业务写入、签名发布或远端推送。

## Pixel 8 登录准备复验

用户首次登录报告 internal_error。无凭据集成检查复现为 prepareLogin 内部异常；Android 的 rustls 系统证书校验器缺少 JVM 初始化。补齐应用启动时 JNI 初始化和 Cargo 配套 Kotlin 校验器依赖后，Pixel 8 上直连与 WebVPN 两条路线均返回 ready。

检查命令：`flutter test --no-pub integration_test/login_preparation_live_test.dart -d emulator-5554 --dart-define=UBAA_LIVE_LOGIN_PROBE=true`，1 项通过。该检查默认跳过，显式开启才访问学校登录页；使用独立的私有配置目录，不提交账号密码。此项更新取代上文“没有真实 Direct/WebVPN 请求”的历史状态，实际账号登录和业务查询仍待用户验证。
