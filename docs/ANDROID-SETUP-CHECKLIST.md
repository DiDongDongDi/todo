# Android 真机体验 — 分工清单

目标：在 **Android 真机** 上安装并运行 Todo App，验证划动手势与动效。

请按编号逐项完成；完成一项可在 `[ ]` 中打 `x` 变为 `[x]`。

---

## 一、Agent 可完成（代码 / 配置 / 命令）

> 你在对话里说「请完成 Agent 清单第 N 项」或「帮我把 Agent 能做的都做了」，由我逐项执行。

| # | 事项 | 说明 | 状态 |
|---|------|------|------|
| A1 | Android 权限配置 | 在 `AndroidManifest.xml` 增加麦克风、相册等权限，保证语音 / 选图在真机可用 | `[ ]` |
| A2 | 插件 Android 配置核对 | 检查 `speech_to_text`、`image_picker` 等是否还需额外 manifest / Gradle 配置 | `[ ]` |
| A3 | 应用显示名 | 将启动器名称改为「Todo」等中文名（`android:label`） | `[ ]` |
| A4 | Gradle / 构建脚本优化 | 必要时添加国内 Maven 镜像，减轻首次 `flutter run` 下载失败 | `[ ]` |
| A5 | 环境检查脚本 | 添加 `scripts/check_android_env.ps1`，自动检测 Java、adb、flutter doctor | `[ ]` |
| A6 | 验证构建 | 在你完成「用户清单」后，执行 `flutter build apk --debug` 并修编译错误 | `[ ]` |
| A7 | 验证真机运行 | 在 `flutter devices` 能看到手机后，执行 `flutter run -d android` 并修运行期问题 | `[ ]` |
| A8 | 文档同步 | 根据实际排错结果更新 README / 本清单 | `[ ]` |

---

## 二、需你本机完成（安装 / 硬件 / 交互确认）

> 这些涉及安装 GUI 软件、插手机、点手机弹窗，只能在你电脑上操作。

| # | 事项 | 说明 | 状态 |
|---|------|------|------|
| U1 | 安装 Android Studio | 下载安装 [Android Studio](https://developer.android.com/studio)；安装时勾选 SDK、Platform、**Command-line Tools** | `[ ]` |
| U2 | 接受 SDK 许可 | 终端执行 `flutter doctor --android-licenses`，逐项输入 `y` | `[ ]` |
| U3 | 确认工具链 | 执行 `flutter doctor`，**Android toolchain** 为 ✓ | `[ ]` |
| U4 | 手机开启开发者模式 | 设置 → 关于手机 → 连点版本号 7 次 | `[ ]` |
| U5 | 开启 USB 调试 | 设置 → 开发者选项 → **USB 调试** 打开 | `[ ]` |
| U6 | 连接电脑并授权 | USB 连接电脑；手机弹窗点 **允许 USB 调试**（可勾选始终允许） | `[ ]` |
| U7 | 确认设备可见 | 执行 `flutter devices`，列表中出现你的手机（非仅 Windows / Chrome） | `[ ]` |
| U8 | USB 驱动（若 U7 失败） | 安装手机厂商官方驱动，或换一根支持数据传输的线 | `[ ]` |
| U9 | Windows 开发者模式（可选） | 若构建提示 symlink：`start ms-settings:developers` 开启 **开发人员模式** | `[ ]` |

---

## 三、建议解决顺序

```
你：U1 → U2 → U3
我：A1 → A2 → A3 → A4 → A5（可并行）
你：U4 → U5 → U6 → U7（不行再做 U8、U9）
我：A6 → A7 → A8
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

## 五、当前阻塞摘要（2025-05-29 检查时）

| 阻塞点 | 负责方 | 对应编号 |
|--------|--------|----------|
| `cmdline-tools` 缺失 | 你 | U1 |
| `JAVA_HOME is not set` | 你（随 Android Studio 安装 JDK 可解） | U1 |
| `adb devices` 无手机 | 你 | U4–U8 |
| 语音 / 相册权限未声明 | Agent | A1 |
| 尚未在真机跑通过 | Agent（依赖 U1–U7 完成后） | A6、A7 |

---

## 六、你怎么触发 Agent 项

在 Cursor 对话中直接说，例如：

- 「请完成 A1–A5」
- 「我 U1–U3 做完了，帮我检查并做 A6」
- 「flutter devices 已经能看到手机了，帮我 run android」

每次最好说明刚完成了用户清单哪几项，便于对症排查。
