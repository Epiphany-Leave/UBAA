# 课表与考试

课表模块提供学期、周次、周课表和今日课程；考试模块按学期读取考试安排。两个模块都依赖教务系统数据，并在服务器中转和本地连接模式之间保持同一 DTO 契约。

## 课表能力

- 查询学期列表和周次列表。
- 按学期与周次查看周课表。
- 使用 HorizontalPager 在课表区域跟手拖动换周；相邻周从同一份本地快照同时绘制，松手吸附。箭头和周次选择使用分页动画，到达学期边界不越界。
- 左侧显示完整节次及上下课时间，空课时也显示。研究生导入时保存 `skjcList` 作息表；没有作息表的旧缓存，仅当研究生学期格式及全部已知课程边界与已核验的 01 标准方案一致时，补全标准 14 节。其他方案缺失的时间显示 `--:--`，可手动更新课表获取上游作息表，避免误用另一套时间。
- 查看今日课程摘要。
- 课程详情页面复用周课表中的课程数据。

### 离线学期课表

- 首次登录后，在课表页点击“更新课表”导入整个学期。普通浏览、首页刷新和切换周次只读取本地，不自动查询或更新学校课表。
- 课表页左侧学期名称可切换学期；“导入系统当前学期”用于新学期开学后的首次导入。已保存的历史学期继续保留，未保存的学期需要选中后手动更新。
- 本地直连/WebVPN 的研究生课表从一次 `loadKbxx.do` 响应生成全部周次；本科及服务器中转依次读取该学期全部周课表。
- 所有周次成功后才保存，失败或取消不会覆盖旧课表。页面展示最后成功更新时间，更新失败时仍显示旧课表。
- 首页根据本地日期和周次计算当天课程，不调用今日课表接口。切换学期浏览不影响首页当天课程。
- 课表按成功登录的学号隔离，切换连接模式不删除缓存。注销后关闭离线访问入口，重新登录同一账号后可再次读取该账号缓存。
- 断网重启后可从登录页点击“查看已保存的离线课表”，查看当天课程和周课表；此入口不授予在线登录状态。尚未成功导入时没有离线课表。
- 博雅、签到、希冀和考试不属于此本地课表，不会由课表缓存自动恢复。

### Android 桌面周课表小组件

- 桌面提供“UBAA 周课表”“UBAA 今日课程”（默认宽4×高2格）和“UBAA 近日课程”（默认宽2×高4格），均允许缩放。HyperOS 等桌面的最终格数由桌面测量决定。
- 周课表在矮尺寸显示七天摘要，拉高后显示含时间轴的完整网格；今日/近日以时间、课程、地点列表展示，近日涵盖从今天起三天并支持跨周。点击进入离线周课表。
- 上一周、下一周、回到本周按钮只读本地缓存；手动切换保留到下一自然周，然后自动回到当前周。无覆盖今天的学期时显示最近保存学期的边界周，并标注实际周开始日期。
- 使用原生 AppWidgetProvider、RemoteViews 和 Canvas，无额外小组件框架。系统周期刷新间隔为 30 分钟，实际执行可能被系统省电策略延后；周期刷新不请求学校系统。应用内成功更新课表、切换账号或注销时通知小组件刷新。
- 小组件只读取当前账号的缓存，注销后清空展示；点击入口不授予登录状态。尚未导入课表时引导打开应用。

### 研究生课表

- 与官方 `coursejsp.js` 的“已选课程课表”规则一致：仅展示 `xkjgList.SFYXXKJG=0` 对应教学班的排课；`1` 为预选。按教学班号关联排课与实际日期，同班同时存在预选和已选记录时保留正式记录。升级此筛选规则后，需要手动更新课表一次以替换旧缓存。

- 本科课表不可用时直接尝试 YJSXK 选课系统的 `xsxkCourse/loadKbxx.do?sfyx=0`，不依赖 GSMIS 门户探测。成功后，本次登录的课表请求继续使用研究生数据源。
- 已适配 WebVPN 将 `/wengine-vpn/js/main.js` 引导脚本插入 `PKSJDDMS` 字符串、破坏 JSON 引号的问题：仅在 JSON 解析失败时移除已识别的网关注入脚本后重试；合法 JSON、普通 HTML 和其他脚本不改写，排课字段仍严格校验。
- 通过官方 `*default/index.do` 入口建立选课系统会话；`course.html` 是公开静态页面，不能用它判断登录成功。本地连接报错区分登录、课表请求和解析阶段，只显示阶段、HTTP 状态或异常类型，不显示 Cookie 或响应正文。
- 学期来自当前已选课表响应；该接口没有返回的历史学期不会凭空生成。
- 按周次位图筛选排课，同一教学班、地点、教师及周次的连续节次合并显示。节次和时刻均来自上游，支持第 14 节晚课。
- 用实际排课日期与周次交叉校验第 1 周的星期一；缺少对应日期或调课造成冲突时不猜测校历。位图长度仅作为可查询周次范围，不代表官方学期长度。
- 已选但未排课的课程不会伪造上课时间；当前周没有排课可以正常显示空课表。
- 直连/WebVPN 需要更新客户端；服务器中转需要部署包含此适配的后端，安装新 APK 不会更新公共服务器。
- 研究生考试安排仍未接入，本次课表适配不改变考试接口的支持范围。

本地可用 `UBAA_GRADUATE_SCHEDULE_SAMPLE` 指定仓库外的原始响应文件，并运行 `:shared:jvmTest --tests '*GraduateSchedule*'`，逐周校验排课。请勿把包含个人信息或登录 Cookie 的响应提交到仓库。

也可用 `-PgraduateScheduleSample=样本绝对路径` 显式指定样本；Gradle 将文件纳入测试输入，未指定样本时该项显示为跳过。
本地直连/WebVPN 的 JSON 解析失败时，课表页可手动复制本次响应以复现问题。响应只留在内存，不自动复制或发送，不包含请求头；仍可能包含姓名、学号和课程信息，请勿公开发布。

## 考试能力

- 按学期查询考试安排。
- 展示考试名称、时间、地点、座位号等考试信息。
- 通过 ViewModel 的 `ensureLoaded()` 避免页面重复加载。

## 技术路径

- `ScheduleApiBackend` 和 `RelayScheduleApiBackend` 负责 relay 模式接口。
- `LocalScheduleApiBackend` 在本地连接模式下访问本科教务上游。
- 服务器的 `ScheduleService` 适配上游课表接口，`ScheduleRoutes` 暴露统一 HTTP API。
- 考试模块通过 `ExamService` 和 `ExamRoutes` 提供 `/api/v1/exam/list`。

## 接口

- `GET /api/v1/schedule/terms`
- `GET /api/v1/schedule/weeks?termCode=...`
- `GET /api/v1/schedule/week?termCode=...&week=...`
- `GET /api/v1/schedule/today`
- `GET /api/v1/exam/list?termCode=...`

## 来源文件

- `composeApp/src/commonMain/kotlin/cn/edu/ubaa/ui/screens/schedule/ScheduleScreen.kt`
- `composeApp/src/commonMain/kotlin/cn/edu/ubaa/ui/screens/schedule/ScheduleViewModel.kt`
- `composeApp/src/commonMain/kotlin/cn/edu/ubaa/ui/screens/exam/ExamScreen.kt`
- `composeApp/src/commonMain/kotlin/cn/edu/ubaa/ui/screens/exam/ExamViewModel.kt`
- `shared/src/commonMain/kotlin/cn/edu/ubaa/api/feature/ScheduleApi.kt`
- `shared/src/commonMain/kotlin/cn/edu/ubaa/api/local/LocalScheduleApi.kt`
- `shared/src/commonMain/kotlin/cn/edu/ubaa/model/dto/Schedule.kt`
- `shared/src/commonMain/kotlin/cn/edu/ubaa/model/dto/Exam.kt`
- `server/src/main/kotlin/cn/edu/ubaa/schedule/ScheduleRoutes.kt`
- `server/src/main/kotlin/cn/edu/ubaa/schedule/ScheduleService.kt`
- `server/src/main/kotlin/cn/edu/ubaa/exam/ExamRoutes.kt`
- `server/src/main/kotlin/cn/edu/ubaa/exam/ExamService.kt`
- `server/src/test/kotlin/cn/edu/ubaa/schedule/ScheduleRoutesTest.kt`
- `server/src/test/kotlin/cn/edu/ubaa/exam/ExamRoutesTest.kt`
