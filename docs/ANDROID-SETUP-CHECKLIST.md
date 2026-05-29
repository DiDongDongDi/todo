# Android 真机体验 — 分工清单

目标：在 **Android 真机** 上安装并运行 Todo App，验证划动手势与动效。

相关：[Web 调试清单](WEB-SETUP-CHECKLIST.md)（日常开发，无需 Android Studio）

请按编号逐项完成；完成一项可在 `[ ]` 中打 `x` 变为 `[x]`。

---

## 一、Agent 可完成（代码 / 配置 / 命令）

> 你在对话里说「请完成 Agent 清单第 N 项」或「帮我把 Agent 能做的都做了」，由我逐项执行。

| # | 事项 | 说明 | 状态 |
|---|------|------|------|
| A1 | Android 权限配置 | `AndroidManifest.xml`：INTERNET、RECORD_AUDIO、READ_MEDIA_IMAGES 等 | `[x]` |
| A2 | 插件 Android 配置核对 | 见 [ANDROID-PLUGIN-NOTES.md](ANDROID-PLUGIN-NOTES.md) | `[x]` |
| A3 | 应用显示名 | 启动器名称已改为 **Todo** | `[x]` |
| A4 | Gradle 国内镜像 | `settings.gradle.kts`、`build.gradle.kts` 已加阿里云 Maven | `[x]` |
| A5 | 环境检查脚本 | `scripts/check_android_env.ps1` | `[x]` |
| A6 | 验证构建 | 已尝试；**阻塞：JAVA_HOME 未设置**（需你完成 U1） | `[ ]` 待 U1 |
| A7 | 验证真机运行 | 需 `flutter devices` 可见手机（需你完成 U4–U7） | `[ ]` 待你 |
| A8 | 文档同步 | 本清单、README、插件说明已更新 | `[x]` |

### Agent 已改动的文件

- `app/android/app/src/main/AndroidManifest.xml`
- `app/android/settings.gradle.kts`
- `app/android/build.gradle.kts`
- `scripts/check_android_env.ps1`
- `docs/ANDROID-PLUGIN-NOTES.md`

---

## 二、需你本机完成（安装 / 硬件 / 交互确认）

> 这些涉及安装 GUI 软件、插手机、点手机弹窗，只能在你电脑上操作。

| # | 事项 | 说明 | 状态 |
|---|------|------|------|
| U1 | 安装 Android Studio | 下载安装 [Android Studio](https://developer.android.com/studio)（**Stable** 即可；代号 Panda 见 [ANDROID-STUDIO-VERSION-NAMES.md](ANDROID-STUDIO-VERSION-NAMES.md)）；勾选 SDK、Platform、**Command-line Tools** | `[ ]` |
| U2 | 接受 SDK 许可 | 终端执行 `flutter doctor --android-licenses`，逐项输入 `y` | `[ ]` |
| U3 | 确认工具链 | 执行 `flutter doctor`，**Android toolchain** 为 ✓ | `[ ]` |
| U4 | 手机开启开发者模式 | 设置 → 关于手机 → 连点版本号 7 次 | `[ ]` |
| U5 | 开启 USB 调试 | 设置 → 开发者选项 → **USB 调试** 打开 | `[ ]` |
| U6 | 连接电脑并授权 | USB 连接电脑；手机弹窗点 **允许 USB 调试**（可勾选始终允许） | `[ ]` |
| U7 | 确认设备可见 | 执行 `flutter devices`，列表中出现你的手机（非仅 Windows / Chrome） | `[ ]` |
| U8 | USB 驱动（若 U7 失败） | 安装手机厂商官方驱动，或换一根支持数据传输的线 | `[ ]` |
| U9 | Windows 开发者模式（可选） | 若构建提示 symlink：`start ms-settings:developers` 开启 **开发人员模式** | `[ ]` |

### 你完成 U1–U3 后请运行

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_android_env.ps1
```

脚本会检查 Java、adb、cmdline-tools、已连接设备，并输出 `flutter doctor` 摘要。

改过系统 Path 后终端仍找不到 `flutter` / `adb`：见 [WINDOWS-DEV-ENV-NOTES.md](WINDOWS-DEV-ENV-NOTES.md)。

---

## 三、建议解决顺序

```
你：U1 → U2 → U3
我：A1–A5、A8（已完成）
你：U4 → U5 → U6 → U7（不行再做 U8、U9）
我：A6 → A7（你完成后叫我）
你：真机体验收集 / 处理手势
```

---

## 四、完成标准

全部满足即表示「可以在安卓手机上体验」：

- [ ] `flutter doctor` 中 Android toolchain 为 ✓
- [ ] `flutter devices` 能看到真机
- [ ] `cd app && flutter run -d android` 成功安装并启动
- [ ] 收集 Tab：输入文字 → 上划保存
- [ ] 处理 Tab：左滑 / 右滑 / 上下切卡有跟手反馈

---

## 五、当前阻塞摘要

| 阻塞点 | 负责方 | 对应编号 | 状态 |
|--------|--------|----------|------|
| `cmdline-tools` 缺失 | 你 | U1 | 待处理 |
| `JAVA_HOME is not set` | 你 | U1 | 待处理 |
| `adb devices` 无手机 | 你 | U4–U8 | 待处理 |
| 语音 / 相册权限未声明 | Agent | A1 | **已解决** |
| APK 未构建验证 | Agent | A6 | 等你 U1 后我继续 |
| 真机未跑通 | Agent | A7 | 等你 U7 后我继续 |

---

## 六、你怎么叫我继续

完成 **U1–U3** 后说：

> 「U1–U3 做完了，帮我检查并构建」

完成 **U4–U7** 后说：

> 「手机已连接，帮我 run android」

---

## 七、U1 完成后可选：自动设置 JAVA_HOME

Android Studio 自带 JDK，路径通常为：

```
C:\Program Files\Android\Android Studio\jbr
```

可在「系统环境变量」中新建 `JAVA_HOME` 指向该目录，并将 `%JAVA_HOME%\bin` 加入 Path（安装 Studio 后若 `flutter doctor` 仍报 Java 错误再设）。
