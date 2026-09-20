# 博雅手机日历

仅复用已读取的博雅详情和已选课程字段；学校请求、CAS、Cookie、路线、加密、缓存、错误合同全部不变。
冻结参考已校验：ubaa_old 6e75e120；buaa-api efb7976b。
旧版 LocalBykcApi / DTO Bykc 提供 courseStartDate、courseEndDate、courseSelectStartDate；
buaa-api api/boya/data.rs 的 Schedule 提供课程/选课时间，utils/time.rs 使用 UTC+8。
两个参考均未提供本次手机日历冲突检测与系统编辑页流程，不新增或推测学校端点。

Core facade 负责时间规范化、草稿和区间判断，bridge 仅转发；平台负责权限、日历查询、系统编辑页。
Android 不申请 WRITE_CALENDAR。iOS 17 读取请求 full access，但应用不直接保存事件。
日历内容不持久化、不上传、不记录诊断；系统日历可能按用户选择的账户自行同步。

TDD：calendar integration test 首次因缺少 facade 接口 E0432 失败（符合预期）。
真机和 iOS 构建验收结果另行记录，不以 mock 替代。

## 当前验证

交付包：`output/UBAA2-pixel8-boya-calendar-ui25.apk`，154492358 字节，x86_64 debug，应用名 UBAA。
SHA-256：`8b2c8e6f0440b67c52bcab1bf99b78eed027c25818504c66940eb1441d63daad`。
aapt 核对最终 APK 含 READ_CALENDAR，不含 WRITE_CALENDAR；最终敏感扫描 946 个文件通过。

- Core lib 248 项与新增日历规则 1 项通过；平台通道 5 项、日历 UI 5 项通过。覆盖拒绝授权、不可靠返回/取消不能声称保存成功、错误不泄露日历内容、预告/已选入口、离开页面或后台清除结果、迟到响应丢弃、只有明确选课成功才跳转到已选课程。
- 既有博雅写操作 7 项通过；3 项旧查询 UI 测试仍寻找已不存在的“课程列表”和旧输入控件而失败。
- UI/App/Host/Platform/Flutter 宿主 analyze 通过；Android x86_64 debug 构建通过。
- 扩大回归检查：UI widgets 套件 59 通过、38 失败（含旧 golden/查询控件断言）；Platform 全套 54 通过、1 失败（Windows 默认路径断言期望 UBAA，实际 Roaming/UBAA）。未修改这些无关旧断言或更新 golden。
- refs 通过；敏感扫描通过。just check 在 references shell 自测 `/tmp` 与 Windows Temp 表达差异失败；layout-check 的既有 libbook.dart 1119 行、queries.dart 1057 行超限尚未解决。本次新增 UI 测试放入 calendar 子目录，不新增目录文件数超限。
- 未执行真实学校选课、自动添加日历或 direct/WebVPN 登录；本次没有修改学校协议。iOS 仅源码适配，Windows 不具备 Xcode 编译验收条件。

## 用户手动验收（Pixel 8，再检查小米系统日历）

1. 安装 ui25，博雅课程详情（包含预告课程）点击“检测日程冲突”。首次拒绝权限应显示“未完成检测”，仍可使用原选课按钮。
2. 在系统设置授予日历权限；在手机日历手动建立与某门博雅课程重叠的测试事件（可用已有个人日程），再次检测，应看到名称、时间、地点和所属日历。
3. 用系统日历建立重复、全天、跨天事件测试；相邻但不重叠的事件不应显示，空闲事件应标记为空闲。
4. 在“我的课程”点击“添加课程日程”，核对预填内容；取消不应显示添加成功，确认保存后在系统日历查看。无需为验收新增真实选课。
5. 预告课程点击“添加选课提醒”，核对开放选课时间，在 Android 日历编辑页选择提前 5 分钟提醒并保存；iOS 预填此提醒。通知由系统日历负责，需该日历自身允许通知。
6. 返回详情、离开页面或切换账号后，旧冲突详情不能残留；撤销权限后再次检测不能误报无冲突。其他平台应隐藏可选日历入口。

手机日历只包含已存于设备、系统提供访问的事件；未同步的云端日程无法由本功能检测。系统编辑页支持用户重复添加，本轮不静默删除或同步已有日程。
