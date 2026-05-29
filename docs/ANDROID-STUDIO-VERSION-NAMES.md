# Android Studio 版本命名说明

> 笔记：解答「Android Studio Panda 4 是什么、能不能装」。

## 结论（一句话）

**Panda 是 Google 官方版本代号，Panda 4 是这一代里的第 4 次更新；装 Stable 稳定版即可，从 [developer.android.com/studio](https://developer.android.com/studio) 下载。**

---

## 为啥名字里有个 Panda？

Google 长期用**动物代号**命名 Android Studio 大版本，类似 Ubuntu 的命名方式。

| 代号 | 大致时期 |
|------|----------|
| Koala | 2024 |
| Ladybug | 2024 |
| Meerkat / Narwhal / Otter | 2025 |
| **Panda** | **2026 年前后（对应 2025.3.x）** |

因此安装程序或关于界面显示 **Android Studio Panda**，属于正常现象，不是第三方山寨名称。

---

## 「Panda 4」里的 4 指什么？

**不是**「第 4 代 Android Studio」，而是 **Panda 这一代中的第 4 个 Feature Drop / 补丁线**。

版本号对应关系示例：

| 显示名称 | 版本号示例 |
|----------|------------|
| Panda（这一代） | 2025.3.x |
| Panda 4 | 2025.3.4 |

可以理解为：

```
Panda（大代号）
  ├── Panda 1 / 2 / 3 / 4 …（同一代内的小版本迭代）
  └── 之后会有下一代代号（如 Quail 等）
```

官方发布说明：

- [Android Studio Panda 4 now available](https://androidstudio.googleblog.com/2026/04/android-studio-panda-4-now-available.html)
- [Android Studio Release Updates（总博客）](https://androidstudio.googleblog.com/)

---

## 该装 Stable 还是 Canary？

| 渠道 | 含义 | 是否推荐日常开发 |
|------|------|------------------|
| **Stable** | 稳定版 | **推荐**（Flutter / 真机调试） |
| RC | 发布候选 | 一般不必 |
| Canary | 早期预览 | 可能不稳定，不必装 |

本 Todo 项目：**安装 Stable**，并在安装向导中勾选：

- Android SDK
- Android SDK Platform（建议 API 34+）
- **Android SDK Command-line Tools**

---

## 如何确认下载来源正确？

- 官网：[https://developer.android.com/studio](https://developer.android.com/studio)
- 发布方为 Google / Android Developers
- 相关域名：`developer.android.com`、`androidstudio.googleblog.com`
- 安装后能打开 IDE，且在 **SDK Manager** 中可管理 SDK

---

## 与本项目的关系

完成 Android Studio 安装后，继续 [ANDROID-SETUP-CHECKLIST.md](ANDROID-SETUP-CHECKLIST.md) 中的：

- **U2** — `flutter doctor --android-licenses`
- **U3** — `flutter doctor` 中 Android toolchain 为 ✓

环境检查脚本：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_android_env.ps1
```

---

## 参考

- [Android Studio（Wikipedia）](https://en.wikipedia.org/wiki/Android_Studio) — 版本代号列表
- [Android Studio Releases List（JetBrains）](https://plugins.jetbrains.com/docs/intellij/android-studio-releases-list.html) — 版本号与代号对照
