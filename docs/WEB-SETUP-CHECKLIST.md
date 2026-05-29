# Web（Chrome）调试 — 分工清单

目标：在 **浏览器（Chrome）** 中运行 Todo App，用于日常开发、热重载与逻辑调试。

> 手势与动效的最终体验仍以 [Android 真机清单](ANDROID-SETUP-CHECKLIST.md) 为准；Web 是**日常首选**，不是功能完全等价环境。

请按编号逐项完成；完成一项可在 `[ ]` 中打 `x` 变为 `[x]`。

---

## 一、Agent 可完成（代码 / 配置 / 命令）

> 在对话里说「请完成 Web 清单第 N 项」或「帮我把 Web Agent 项都做了」。

| # | 事项 | 说明 | 状态 |
|---|------|------|------|
| A1 | `web/index.html` / `manifest.json` | 页面标题、描述、PWA 基础配置 | `[x]` |
| A2 | Web 插件与能力说明 | 见 [WEB-PLUGIN-NOTES.md](WEB-PLUGIN-NOTES.md) | `[x]` |
| A3 | 环境检查脚本 | `scripts/check_web_env.ps1` | `[x]` |
| A4 | 验证 Web 构建 | `flutter build web` → `build/web` | `[x]` |
| A5 | 验证 Chrome 运行 | `flutter run -d chrome`（需你本机有 Chrome） | `[ ]` 可按需 |
| A6 | Web 局限与快捷键文档 | 见 [WEB-LIMITATIONS.md](WEB-LIMITATIONS.md) | `[x]` |
| A7 | 文档同步 | README、本清单、与 Android 清单互链 | `[x]` |

### Agent 已改动的文件

- `app/web/index.html`
- `app/web/manifest.json`
- `scripts/check_web_env.ps1`
- `docs/WEB-PLUGIN-NOTES.md`
- `docs/WEB-LIMITATIONS.md`

---

## 二、需你本机完成（很少）

> Web 环境要求远低于 Android；多数情况下 **装好 Flutter + Chrome 即可**。

| # | 事项 | 说明 | 状态 |
|---|------|------|------|
| U1 | 安装 Chrome | [Google Chrome](https://www.google.com/chrome/) 或已安装的 Chromium 系浏览器 | `[ ]` |
| U2 | Flutter 在 PATH 中 | 终端能执行 `flutter --version`；改 Path 后需**完全退出并重启 Cursor**，见 [WINDOWS-DEV-ENV-NOTES.md](WINDOWS-DEV-ENV-NOTES.md) | `[ ]` |
| U3 | 启用 Web 支持（若未启用） | `flutter config --enable-web`（新版 Flutter 通常默认已启用） | `[ ]` |
| U4 | 确认设备可见 | `flutter devices` 中出现 **Chrome (web)** 或 **Edge (web)** | `[ ]` |
| U5 | 首次运行 | `cd app` → `flutter pub get` → `flutter run -d chrome` | `[ ]` |

### 一键检查

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_web_env.ps1
```

若 Path 已配置仍报 `[FAIL] flutter in PATH`，多半是 Cursor 未重启导致终端继承旧环境，见 [WINDOWS-DEV-ENV-NOTES.md](WINDOWS-DEV-ENV-NOTES.md)。

---

## 三、与 Android 清单对比：Web 还差什么？

| 能力 | Web（Chrome） | Android 真机 |
|------|---------------|--------------|
| Flutter SDK | 需要 | 需要 |
| 额外大型 IDE | **不需要** Android Studio | 需要（U1–U3） |
| USB / 真机 | 不需要 | 需要（U4–U7） |
| 划动手势手感 | 鼠标/触控板，与手机不同 | 真实触控 |
| 语音输入 | 受限（浏览器权限 + 插件支持） | 系统 STT |
| 触觉反馈 | 无 | 有 |
| 热重载速度 | **快** | 较快 |
| 当前构建状态 | **`flutter build web` 已通过** | 待 JAVA_HOME + 真机 |

**结论：** Web 侧**几乎就绪**；你只需确认 Chrome + 跑一条 `flutter run -d chrome`。

---

## 四、建议解决顺序

```
你：U1 → U2 → U3 → U4（通常 10 分钟内）
我：A1–A4、A6–A7（已完成）
你：U5 日常开发
（并行）Android 清单 U1–U7 用于手势打磨
```

---

## 五、完成标准

- [ ] `flutter devices` 能看到 `Chrome (web)` 或 `Edge (web)`
- [ ] `cd app && flutter run -d chrome` 能打开应用
- [ ] 收集 Tab：输入文字 → 上划保存
- [ ] 处理 Tab：键盘 `←` `→` `↑` `↓` 或鼠标操作可分拣任务
- [ ] 热重载：改代码后终端按 `r` 能刷新

---

## 六、当前阻塞摘要

| 阻塞点 | 负责方 | 状态 |
|--------|--------|------|
| Flutter 未安装 | 你 | 若已装则 ✓ |
| 无 Chrome / Edge | 你 | U1 |
| Web 未启用 | 你 | U3（少见） |
| 语音在浏览器不可用 | 预期限制 | 见 WEB-LIMITATIONS |
| 手势与手机不一致 | 预期限制 | 用 Android 清单验证 |

**无 Android Studio / 无真机也可完成 Web 清单。**

---

## 七、日常命令速查

```powershell
cd app
flutter pub get
flutter run -d chrome

# 热重载 r | 热重启 R | 退出 q
# 生产构建
flutter build web
# 输出在 build/web，可部署到任意静态托管
```

---

## 八、你怎么叫我继续

- 「帮我在 Chrome 跑起来」→ 我执行 A5 并排错
- 「Web 构建失败」→ 贴终端报错
- 「手势要调」→ 转 [ANDROID-SETUP-CHECKLIST.md](ANDROID-SETUP-CHECKLIST.md)
