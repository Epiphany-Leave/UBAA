# Android 真机交付检查（2026-09-22）

Debug 模拟器通过不能代替 Release 真机验收。每次交付必须检查最终 APK，不能只检查源码或 Gradle 成功状态。

## 已确认的问题与修复

| 问题 | 证据 | 防止复发 |
| --- | --- | --- |
| Pixel 8 的 x86_64 APK 无法安装到 ARM64 手机 | 旧 ui26 APK 仅含 x86_64 | 手机交付检查三份 arm64-v8a 库：Flutter、Dart AOT、Rust bridge |
| Release 未申请联网权限 | 原始 APK 权限清单无 INTERNET，debug/profile 有 | main manifest 声明；检查成品权限 |
| Release R8 删除 TLS JNI 类，HTTPS 失败 | network-fix APK 无 CertificateVerifier；usage.txt 列出被删除的 verifier 类 | 使用依赖 README 的精确 keep 规则；检查成品 DEX 中的三个 JNI 类 |
| Java 25 构建失败 | 原构建报 25.0.2 | 使用现有 run-ubaa2.ps1 选择 JDK 17 |
| Codex Windows 构建环境问题 | Java Unix socket 临时路径、Pub 缓存虚拟化、缺少 FLUTTER_ROOT 均曾阻止打包 | 本机设置短 jdk.net.unixdomain.tmpdir、真实 PUB_CACHE 和 FLUTTER_ROOT；不改全局系统设置 |

## 自动检查

在仓库根目录运行，JAVA_HOME 应指向现有 JDK 17：

```powershell
powershell -NoProfile -File scripts/release/check-android-apk.ps1 -Apk output/arm64/UBAA2-arm64-release-tls-fix.apk -BuildTools "$env:ANDROID_HOME/build-tools/36.0.0"
```

检查 Release 标记、联网权限、指定 ABI 的三份原生库、TLS JNI 类、签名与 16 KB ZIP 对齐。该脚本对旧 network-fix APK 实际失败，原因是缺失 CertificateVerifier。它不是网络可用性或登录成功的证明。

## 其他检查与限制

- 最低 Android API 24；Redmi Turbo 3 不受此最低版本限制。
- Rust bridge 的 ELF LOAD 对齐已核对为 0x4000（16 KB）；ZIP 对齐另行检查。不能把 ZIP 检查等同于所有设备的运行验收。
- 当前 Release 仍使用 debug 签名，versionName/versionCode 为 0.1.0/1。可用于当前个人测试；正式发布前须配置持久发布密钥并递增版本，不能随意换签名导致无法覆盖安装。
- 相机通过系统 Intent/FileProvider，日历读取在使用时申请权限；拒绝或取消仍需真机复测。未发现必须为这些系统 Intent 额外申请广泛存储权限的依据。
- 本次不修改身份识别、学校接口、TLS 安全校验或账号数据。

## 每次人工验收

1. 在目标手机覆盖安装待交付的同一个 Release APK，冷启动，确认版本和签名来源。
2. 用户登录，验证所用直连/WebVPN 模式；验证课表及一次普通查询。勿在日志记录密码、Cookie 或响应正文。
3. 重开应用验证会话/安全存储；验证桌面组件、相机选择和日历拒绝/取消路径。
   普通按 Home 后切回应保留当前页面与数据；多级页面的系统返回手势应逐层返回。强杀重开和普通后台恢复须分别验收。
4. 分别记录设备、系统、网络、APK 文件及结果。未在实体设备通过时明确标记“待真机确认”，不能宣称全部兼容。

当前 TLS 修复版仍待用户在 Redmi Turbo 3 验证登录。诊断中的 cause=unknown 不能区分所有网络故障；如果仍失败，需要继续采集安全的故障类别或设备日志，不盲目关闭证书校验。
