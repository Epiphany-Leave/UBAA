# PR #97：提交状态与学业身份隔离复核

## 提交和验收范围

- 来源：`Epiphany-Leave/UBAA:UBAA2`；目标：`BUAASubnet/UBAA:ubaa2`。
- PR：https://github.com/BUAASubnet/UBAA/pull/97 ，保持 Draft。
- 语言功能提交 `9c89a307a5dc06394fd718afc1a4921dc6ab5202` 的四项 CI 全部成功：https://github.com/Epiphany-Leave/UBAA/actions/runs/35493174479 。这是来源分支验证，不是 PR 合并结果验证。
- 本次仅扩大身份隔离回归测试并记录审查结果，不改变生产请求、协议、界面或依赖。
- 用户报告 Pixel 8 对博雅日历进行了轻度测试；不将其扩大解释为完整权限边界、iOS 或本科真实账号均已验收。

## 隔离链路

1. `features/user.rs` 使用学校返回的 `school_id`，缺失时才使用账号名，写入当前路线运行时的身份。
2. `facade/read/academic.rs` 在课表、考试、成绩和整学期导入前确认身份；恢复会话缺身份时，先读取当前用户信息。未知身份拒绝请求。
3. `features/schedule.rs` 识别八位数字本科号码和字母前缀研究生号码；ASCII 字母大小写均支持。九位继续教育号码及无法识别的号码不按本科处理。
4. 本科调用原本科门户／成绩服务，研究生调用 GSMIS。错误响应、空响应或解析失败不触发跨身份数据源回退。
5. `session/schedule_cache.rs` 按所属账号保存学期；切换账号先关闭旧缓存入口，写入前再检查所属账号，注销关闭入口。底层传输与 Cookie 工具共用，不表示两种学业接口互相回退。

## 可复现检查

`cargo test --locked -p ubaa-core --all-features` 通过，涵盖内部请求、facade、路线矩阵、缓存和会话测试。

本次扩展 `known_student_identity_never_switches_system_on_failure`：本科与多种大小写研究生号码分别运行 Direct／WebVPN；模拟 HTTP 503，检查学期、考试学期、教学周、周课表、今日课程、考试、成绩、整学期导入和研究生成绩概览。每个请求都必须落在该身份允许的、经当前路线转换的 URL 前缀中，并断言确实发送了请求，避免仅因输入校验失败而产生假通过。

既有 `unknown_identity_blocks_all_academic_requests_before_network`、`restored_session_recovers_identity_once_and_rejects_unknown_numbers`、`complete_semester_only_account_isolation_and_logout` 同时保留。Mock 通过不代替两个真实身份的校园系统验收。

冻结引用校验、敏感扫描与 `git diff --check` 通过。CI 的全量检查仍以对应提交的 GitHub Actions 实际结果为准。

## 尚未完成的上游整合

上游目标提交 `0f73bd2ce57c0c2d05596361aa73dedeaab6861e` 比共同基线多 41 个提交；当前分支有 8 个本地功能／验收提交。预检有 77 个冲突文件，其中 26 个为视觉基线。

用户已选择保留验证过的本地界面、逐项兼容上游。一次合并尝试发现两套 UI 的导航、筛选位置、数据投影、读取生命周期和测试入口相互依赖，已撤回未完成的合并，避免上传无法构建的混合版本。没有通过删除上游测试、跳过 CI 或覆盖整组基线来消除冲突。

后续必须逐项完成数据投影与读取生命周期兼容、原生日历／照片 MethodChannel 接线、界面行为回归及合并结果 CI；移除这些阻塞前，不标记为可合并或项目验收完成。维护者最终接受与否由其审查决定。
