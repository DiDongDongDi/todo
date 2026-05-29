# Flutter 与 Dart 入门笔记

> 本文档整理自项目开发过程中的基础概念说明，便于快速回顾。

## `*.dart` 是什么文件？

`*.dart` 是 **Dart 语言** 的源代码文件。

### 简要说明

- **扩展名**：`.dart`
- **语言**：Dart（由 Google 开发）
- **用途**：编写程序逻辑，包括变量、函数、类、界面等

### 和本项目的关系

本项目的 `app/lib/` 目录下有很多 `.dart` 文件，说明这是一个 **Flutter** 应用。Flutter 使用 Dart 编写跨平台 UI 和业务逻辑，可编译到：

- Android
- iOS
- Web
- Windows / macOS / Linux

常见文件示例：

| 文件 | 作用 |
|------|------|
| `main.dart` | 应用入口 |
| `app.dart` | 根 Widget / 应用配置 |
| `task.dart` | 数据模型 |
| `collect_screen.dart` | 「收集」页面 UI |
| `app_theme.dart` | 主题样式 |

### `*.dart` 里的 `*` 是什么意思？

在文件匹配（glob）语法中，`*` 是通配符，表示「任意文件名」：

- `*.dart` = 所有以 `.dart` 结尾的文件
- 例如 `main.dart`、`task.dart` 都符合这个模式

### 和类似扩展名的区别

| 扩展名 | 语言/用途 |
|--------|-----------|
| `.dart` | Dart（Flutter 应用） |
| `.js` / `.ts` | JavaScript / TypeScript（Web） |
| `.py` | Python |
| `.java` / `.kt` | Java / Kotlin（Android 原生） |
| `.swift` | Swift（iOS 原生） |

---

## Flutter 是什么？

**Flutter** 是 Google 推出的**跨平台 UI 框架**，用于用一套代码构建能在多个平台上运行的应用。

### 一句话理解

用 **Dart** 写界面和逻辑，Flutter 帮你编译/运行在 **手机、电脑、网页** 上，而不必为每个平台各写一套原生代码。

### 它解决什么问题？

传统做法通常是：

- Android → 用 Kotlin/Java
- iOS → 用 Swift
- Web → 用 JavaScript
- Windows → 用 C# 等

同一款应用可能要维护多套代码。Flutter 的思路是：**大部分代码写一次，多端复用**。

### 和本项目的关系

`app/` 目录就是一个 Flutter 项目：

- `pubspec.yaml` — 依赖和项目配置（类似 `package.json`）
- `lib/*.dart` — 应用源代码
- `main.dart` — 程序入口

本「上瘾待办」应用借助 Flutter 实现跨平台（Android、iOS、桌面、Web 等）。

### Flutter 的核心特点

| 特点 | 说明 |
|------|------|
| **跨平台** | 一套代码，多端运行 |
| **自绘 UI** | 不依赖系统原生控件，界面在各平台更一致 |
| **热重载（Hot Reload）** | 改代码后能快速看到效果，开发效率高 |
| **Widget 体系** | 界面由大量小部件（Widget）组合而成，如按钮、列表、页面 |
| **性能较好** | 编译成原生机器码，接近原生应用体验 |

### 和 Dart 的关系

- **Dart**：编程语言（写 `.dart` 文件）
- **Flutter**：基于 Dart 的 UI 框架（提供按钮、布局、动画、路由等）

可以类比为：

- JavaScript + React（Web）
- Dart + Flutter（跨平台应用）

### 常见使用场景

- 手机 App（Android / iOS）
- 桌面应用（Windows / macOS / Linux）
- Web 应用
- 嵌入式设备等

### 和其他跨平台方案的对比（简要）

| 方案 | 特点 |
|------|------|
| **Flutter** | 自绘 UI，性能好，界面一致性强 |
| **React Native** | 用 JavaScript，更接近调用原生组件 |
| **原生开发** | 每个平台单独写，最灵活但成本最高 |

---

## 总结

- **`.dart`** = Flutter/Dart 项目的源代码文件
- **Flutter** = 用 Dart 开发跨平台应用的 UI 框架
- 本项目选择 Flutter，是为了用一套代码覆盖 Android、iOS、桌面和 Web 等多个平台
