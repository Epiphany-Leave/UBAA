# 2026-09-19 四种桌面组件与界面设置

## ui24：滚动周课表与固定今日规格

用户反馈 ui23 周课表挤压、今日占格不符。根因是周网格整图 fitXY 到组件剩余高度。本轮改为固定 52dp 节次，RemoteViews ListView + RemoteViewsService 承载按节次裁切的连续网格，星期/日期表头固定。延续跨节课程与重叠课程几何，不修改缓存内容。列表点击仍显式进入 App 对应学期与周；刷新通知集合数据变化，空课表隐藏列表。采用 [Android 原生集合组件](https://developer.android.com/develop/ui/views/appwidgets/collections) 支持垂直滚动。

今日已声明 targetCellWidth/Height=2、minWidth/Height=110dp，本轮关闭 resizeMode，避免拖成其它比例。旧桌面实例的占格不会由 APK 更新强行移动，需删除后重新添加；其他桌面实现仍需实际验证。未清空用户桌面配置。Android x86_64 debug 构建通过，滚动手势、刷新、点击及占格待用户 Pixel 8 验证。

参考用户提供的 WakeUp 截图：白色圆角容器、今日彩色侧边课程列表、近日按天分栏、周课程彩色网格、日视图彩色课程卡。今日默认 2×2，其余默认 4×2，实际占格取决于桌面。保留 RemoteViews 和 Canvas，不新增库或网络请求。小尺寸周组件继续显示网格，不再切换成文字摘要。

周组件、日视图右上角 ≡ 打开单组件设置：已缓存学期/跟随当前、纯白/暖色/透明背景、课程字号、时间显示；周组件另有周末开关。固定学期不随 App 切换，今日和近日组件跟随 App 选择。日视图提供前后一天/回到今天；固定到不含今天的学期时从该学期首日显示。全部展示数据继续由 Rust Core 缓存经 typed bridge 投影，Android 不读取 Core Session 或构造协议请求，退出登录继续清空展示快照。

参考本地 XDYou `lib/page/setting/setting.dart`、`groups/ui_section.dart`、`groups/classtable_section.dart` 的分类和交互思路，独立实现“我的→界面与课表设置”：模式、主题色、字号、周末、完整时间轴、周次缩略图、节次高度。也从课表菜单进入。只加入已有数据与组件能支持的选项。设置在应用私有目录持久化，复用平台目录解析；串行保存防止快速切换导致写入交错。设置变化不重新查询学校接口。

本轮无协议、认证、Cookie、加密、解析和业务规则变更，因此不借用 XDYou 的学校接口。冻结来源 refs 通过。Flutter 设置与实际课表显示测试、快照字段测试和分析检查用于确定性验证；桌面占格、缩放、独立学期及点击体验仍由用户在 Pixel 8 验收。

验证结果：设置/课表 5 项、快照 2 项、宿主 21 项通过；UI、宿主、平台分析无问题；敏感扫描 931 个已跟踪文件通过。Android x86_64 debug 构建成功，交付 `output/UBAA2-pixel8-widgets-settings-ui23.apk`（UBAA，0.1.0，154444425 字节）。完整 check 的 40 项 layout 脚本测试、7 项版本脚本测试通过，后续 references 脚本测试仍因 Windows `/tmp` 与 `C:/Users/.../Temp` 路径比较失败；不宣称全量门禁通过。未执行真实业务写入。

实际 layout-check 另报告已有的 `libbook.dart` 1119 行、`test/widgets/queries.dart` 1057 行超长；这两个文件本轮没有修改。
