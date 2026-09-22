# 线路切换、签到加载与卡片间距

## 根因与修改

- 用户诊断的签到、希冀错误是 `direct/network_error`，切换线路是 `operation_conflict`；不能据此归因为学校服务异常，也没有证据证明 WebVPN 请求本身失败。
- `_beginWriteTransition` 会增加生命周期代次，晚到查询不再回写，但原代码保留 loading，因此一次失败的线路切换即可留下永久转圈。共享收尾将其设为可重试 failure/stale，保留旧数据；签到 stale 页面仍禁止展示旧签到目标。
- `BridgeClient.set_default_route_policy` 的 try_lock 与读取占用 Core 锁冲突。改为与其他 Bridge 操作一致的异步锁等待，仍保持 Core→写意图锁顺序，切换后清空旧意图。UI 显示切换中并禁止重复切换/新查询，注销/重建后晚到切换结果也不回写。
- 统计与个人卡片在全局零 margin 主题下紧贴。显式增加间距；达标文字允许换行，个人页连接说明与选择器上下排布。
- 本轮是宿主并发/展示修复：不更改 Core facade 的路线选择、认证、Cookie、学校 HTTP 请求、数据解析、本研隔离和签到时间规则，不新增第三方依赖。参考协议行为维持已有 source-parity 记录。

## 回归证据

- 修复前，线路切换成功/失败两个回归用例均得到 loading 而非结束状态（`route-loading-before.log`）。Bridge 持锁用例得到 operation_conflict（`route-lock-before.log`）。统计卡片间距实测为 0（`cards-before.log`）。
- 修复后 App 全部 205 项通过；Bridge 113 项通过、2 项忽略；UI 博雅、个人页、设置与签到/返回测试 10 项通过。Bridge clippy 与 Dart 三包 analyze 通过。
- Host 全部 21 项通过。refs、layout-check、敏感扫描和 diff 检查通过；`just check` 本轮再次确认因缺少 zip 停止。
- 全仓门禁的环境阻塞仍为缺少 zip；此前未更新视觉基线等未在本轮覆盖或宣称通过。
- Pixel 8 调试包：`output/pixel8/UBAA2-pixel8-route-cards-test.apk`。不自动提交真实签到。手机上的实际网络查询与视觉效果仍需用户确认，模拟器测试不能替代 ARM64 真机验收。
- 该包已覆盖安装 Pixel 8 并正常启动；aapt 核验为 x86_64、名称 UBAA。本轮未交付新的 ARM64 包。

## 人工步骤

进入“我的”切换 WebVPN，等待进度结束并确认下拉框保留 WebVPN；如该路线未登录，按提示登录。进入签到点击重试/刷新，确认最终显示数据、空状态或错误，而不是持续加载。检查博雅课程统计、我的设置卡片间距。
