# Android 真机安装与版本说明

如何把最新代码装到手机上，以及为什么 `flutter run` 断线后可能「不是最新版」。

相关：[Android 真机分工清单](ANDROID-SETUP-CHECKLIST.md) · [README 真机调试章节](../README.md#android-真机调试手势--动效)

---

## 一、把最新代码装到手机上

本项目是 Flutter 应用，代码在 `app/` 目录。

### 方式一：USB 联调安装（推荐，适合开发）

改代码后可以随时热重载。

#### 1. 拉取最新代码

```powershell
cd C:\Users\kody\github_repos\todo
git pull
```

#### 2. 安装依赖

```powershell
cd app
flutter pub get
```

#### 3. 连接手机

- 手机开启 **开发者选项** 和 **USB 调试**
- 用数据线连电脑，弹出授权时点 **允许**
- 确认设备可见：

```powershell
flutter devices
```

列表里应出现你的手机（不只是 Windows / Chrome）。

#### 4. 构建并安装到手机

```powershell
flutter run -d android
```

首次或依赖变更后构建会较慢，属正常。安装成功后：

| 操作 | 按键 |
|------|------|
| 热重载（改 UI 后） | 终端按 `r` |
| 热重启 | 按 `R` |
| 退出 | 按 `q` |

改完 `lib/` 下代码后按 `r`，手机上的 App 会立刻更新，无需重装。

---

### 方式二：打包 APK 安装（适合离线使用）

不想一直连着电脑，或想装一个「独立 App」时用。

#### 调试版 APK（最快）

```powershell
cd app
flutter pub get
flutter build apk --debug
```

生成文件：

```
app\build\app\outputs\flutter-apk\app-debug.apk
```

把 APK 拷到手机（微信、网盘、数据线均可），在手机上点击安装。若提示无法安装，到 **设置 → 允许安装未知来源应用** 里放行对应来源。

#### 正式版 APK（体积更小、性能更好）

```powershell
flutter build apk --release
```

输出：`app\build\app\outputs\flutter-apk\app-release.apk`

#### 用 adb 直接安装（手机仍连着电脑时）

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

`-r` 表示覆盖安装旧版。

---

### 常见问题

| 问题 | 处理 |
|------|------|
| `INSTALL_FAILED` / 签名冲突 | 先卸载手机上的旧版 **Todo**，再重新安装 |
| `flutter devices` 看不到手机 | 换数据线、重插 USB、确认已允许 USB 调试 |
| `Lost connection to device` | 重新插线，再执行 `flutter run -d android` |
| 首次克隆仓库缺平台目录 | 先运行 `powershell -ExecutionPolicy Bypass -File scripts\init_platforms.ps1` |

### 怎么选？

- **还在改代码、想马上看效果** → 方式一：`flutter run -d android`
- **只想装一个最新版，平时不连电脑** → 方式二：`flutter build apk` 后拷 APK 到手机安装

---

## 二、为什么断线后 App「不是最新版」？

`flutter run -d android` 确实会把 App **安装**到手机上，但它本质是**开发调试模式**，不是「每次打开都自动同步最新代码」。

### 核心原因：热重载的改动不会写回已安装的 APK

`flutter run` 启动时，电脑会编译一版代码并安装到手机。之后你在终端里按 `r` 做**热重载**，改动是注入到**正在运行的 Dart 虚拟机内存**里，并不会更新手机里那份 APK 文件。

典型流程：

```
flutter run  →  安装「构建那一刻」的版本
     ↓
改代码 + 按 r  →  手机上「看起来」是最新的（仅内存里）
     ↓
断开 USB / 关掉 App 再打开  →  冷启动，读的是磁盘上的旧 APK
```

断线本身不会卸载 App，但**冷启动会丢掉只靠热重载生效的改动**，看起来就像「不是最新版」。

### 几种常见场景

| 场景 | 结果 |
|------|------|
| 改代码后只按了 `r`（热重载），然后断线、杀进程再打开 | 回到 `flutter run` 那次构建的版本 |
| 电脑上又 `git pull` 了新代码，但没重新 `flutter run` | 手机仍是旧构建 |
| 改了 `AndroidManifest`、原生插件、资源文件等 | 热重载不够，必须完整重新构建 |
| 一直连着电脑、App 没被杀掉 | 热重载的改动还在，感觉「是最新的」 |

---

## 三、怎么让手机上的版本真正「固定」为最新？

### 开发时（还连着电脑）

改完代码想确认断线后也是新版，在断开前做一次**完整重装**：

```powershell
cd app
flutter run -d android
```

如果已经在跑，先按 `q` 退出，再重新执行上面命令（不要只靠 `r`）。

大改动或动了原生配置时，用热重启或完整重启更稳：

- 终端按 `R`（热重启，比 `r` 彻底）
- 或直接 `q` 退出后重新 `flutter run`

### 想断线后长期使用最新版（推荐）

打包 APK 再安装，改动会**写进安装包**：

```powershell
cd app
flutter build apk --debug
```

然后把 `app\build\app\outputs\flutter-apk\app-debug.apk` 拷到手机安装；或手机连着电脑时：

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

这样不连电脑，打开也是这一版。

---

## 四、一句话总结

| 命令 | 含义 |
|------|------|
| `flutter run` | 装一个**快照** + 提供**临时**热重载通道 |
| 按 `r` | 仅内存生效，断线冷启动后丢失 |
| `flutter build apk` + 安装 | 改动写入 APK，断线后仍是最新 |

如果你希望「手机上永远是我电脑上最新 commit」，每次更新后应 **`flutter build apk` 安装**，或 **`q` 退出后重新 `flutter run`**，不要只依赖 `r`。
