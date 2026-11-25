# 🐱 KeyCat 安全评估与安装记录

> 评估时间：2026-11-25 · 目标：ElloboDK/KeyCat v1.1.1（Windows 端）

## 📌 项目概况

| 项目 | 内容 |
|---|---|
| 仓库 | https://github.com/ElloboDK/KeyCat （注意：是 `ElloboDK`，不是 `EIIoboDK`） |
| 定位 | 菜单栏/托盘桌面宠物黑猫，跟键盘动爪、跟鼠标转头 |
| 版本 | v1.1.1（2026-11-24 发布） |
| 技术 | macOS=Swift；Windows=Tauri(Rust)+WebView2；共用 three.js 场景 |
| 热度 | ⭐181 / Fork 28 / 12 open issues |

## 🔍 审计方法

- 当前 main 分支已于 **2026-11-25 10:11** 移除源码（作者转私有仓库 `ElloboDK/KeyCat-src`）。
- 审计对象：v1.1.1 tag 对应的历史公开 commit `71b2cdb`，源码归档于 `D:\WorkBuddy\_archive\KeyCat-src-audit`。
- 范围：`win/src`（Rust）、`web`（前端）、`.github/workflows`（CI）、`tauri.conf.json`、安装包二进制。

## ✅ 安全结论：**低风险，可安装**

| 检查项 | 结果 |
|---|---|
| 键盘记录外传 | ❌ 未发现。只读物理键名（KeyA/Space）与计数，不取字符、不留按键历史、不上传 |
| 网络出口 | 仅 `github.com` 更新检查/下载；无遥测、无第三方域名、无 C2 |
| 自动更新 | tauri-plugin-updater + minisign 公钥签名校验；私钥仅在 CI Secret |
| 持久化/提权 | 用户菜单显式开启；计划任务仅限 Program Files 路径；无隐蔽自启 |
| 敏感操作 | 无 `cmd /c`、无下载执行、无 eval 注入、无任意文件读写 command |
| 挖矿/后门 | ❌ 未发现 |
| 安装包完整性 | SHA-256 `727ebfe930080842f6037d487f519f53a00316d007974fb883f04b8bad6610ce`，与 GitHub API digest 一致 |
| 代码签名 | 未签名（NotSigned），SmartScreen 会拦截，属正常现象 |

## ⚠️ 已知风险点

1. 🪝 全局键鼠钩子 `WH_KEYBOARD_LL`/`WH_MOUSE_LL`——桌面宠物设计所需，但能力敏感。
2. 🔐 可选「以管理员身份运行」+ 最高权限登录计划任务——需手动开启，非默认。
3. 🛡️ WebView2 启动参数禁用了 `msSmartScreenProtection`；`csp: null`——仅加载本地资源，实际风险低。
4. 🔒 源码已转私有——后续版本无法再公开审计，升级前需自行评估。

## 💻 本机安装状态

- 安装包：`D:\WorkBuddy\_archive\KeyCat-pkg\KeyCat-Windows-Setup.exe`（2.2 MB）
- 沙箱内自动安装失败（UAC 提权被拦截）；`C:\Program Files\KeyCat` 为空，无快捷方式。
- 手动安装：双击 exe → SmartScreen「更多信息 → 仍要运行」→ UAC「是」→ 完成。

## 📚 资料

- 下载页：https://ellobodk.github.io/KeyCat/
- Release：https://github.com/ElloboDK/KeyCat/releases/latest
