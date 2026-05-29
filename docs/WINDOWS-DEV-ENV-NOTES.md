# Windows 开发环境笔记 — PATH 与 Cursor 终端

适用于：已在「系统环境变量」里配置了 Flutter（或其它工具）的 `bin` 目录，但 **Cursor / VS Code 终端里仍找不到命令** 的情况。

---

## 现象

| 操作 | 结果 |
|------|------|
| 系统设置 → 用户 Path 已包含 `C:\Users\<你>\flutter\bin` | 配置看起来正确 |
| 只**关闭终端标签、再点「+」新开** | `flutter` 仍找不到 |
| `scripts/check_web_env.ps1` | `[FAIL] flutter in PATH` |
| 在当前终端执行「从注册表刷新 Path」后 | `flutter` 可用，检查脚本通过 |

本仓库在 Windows 上验证过的 Flutter 路径示例：`C:\Users\kody\flutter\bin`（你的用户名不同时请替换）。

---

## 原因（不是 Path 配错）

1. **注册表里的 Path 是对的**  
   做法 2 能成功，说明 Flutter 已安装，且用户环境变量已写入。

2. **子进程继承父进程环境，不会每次重读注册表**  
   - Cursor（或 VS Code）启动时，会读一次当时的 Path，保存在**主进程**里。  
   - 之后打开的每一个集成终端，都继承这个**主进程**的环境，而不是再去读注册表。  
   - 用 `powershell -File scripts/xxx.ps1` 启动的子 PowerShell，同样继承**当前终端**的 Path。

3. **因此**  
   - 你在 Cursor **已经打开之后**才去改用户 Path → 只新开终端 **不够**。  
   - 必须让 **Cursor 主进程重新启动**，新终端才会带上新的 Path。

```text
注册表 User Path（已更新）
        │
        ├─► 新启动的 Cursor.exe ──► 新终端 ──► flutter 可用
        │
        └─► 未退出的旧 Cursor.exe ──► 任意新终端 ──► 仍是旧 Path
```

---

## 正确做法

### 推荐：完全重启 Cursor

1. 关闭 Cursor **所有窗口**（确认托盘、任务管理器里没有 `Cursor.exe`）。  
2. 重新打开 Cursor 和本项目。  
3. 新开终端验证：

```powershell
Get-Command flutter | Select-Object Source
# 期望：...\flutter\bin\flutter.bat

($env:Path -split ';' | Where-Object { $_ -match 'flutter' })
# 期望：至少一行含 flutter\bin
```

4. 再跑环境检查：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_web_env.ps1
```

### 临时：不重启 Cursor 时刷新当前终端

在**当前** PowerShell 终端执行（对 Flutter、Git、pnpm 等所有「刚加进用户 Path」的项都生效）：

```powershell
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
flutter --version
```

同一窗口内再运行 `check_web_env.ps1` 或其它命令即可。

> 注意：只对**当前终端会话**有效；其它已打开的终端标签各自仍是旧 Path，除非在每个里执行上述一行，或重启 Cursor。

---

## 与「配置有问题」的区分

| 情况 | 刷新 Path（做法 2） | 重启 Cursor 后新终端 |
|------|---------------------|----------------------|
| Path 未配置 / 路径写错 | 仍失败 | 仍失败 |
| Path 已对，Cursor 未重启 | **成功** | 失败 |
| Path 已对，已重启 Cursor | 成功 | **成功** |

---

## 仍失败时再查

- Path 是否加在**当前登录用户**下（不是别的账户）。  
- 条目是否为 `...\flutter\bin`（不是 `...\flutter` 根目录）。  
- 路径中是否有多余引号、空格、分号错误。  
- 本机 Cursor `settings.json` 是否用 `terminal.integrated.env.windows` 覆盖了 `Path`（本仓库默认无此项）。

---

## 检查脚本里的「报错」与乱码

运行 `scripts/check_web_env.ps1` 时若出现：

- 红色 `NativeCommandError` / `flutter.bat : Flutter assets will be downloaded from ...`
- `鈥?`、`鈭歖`、`鐗堟湰` 等乱码（本应是 `•`、`√`、`版本`）

**不代表环境失败**，常见原因：

1. **假报错**：Flutter 把中国镜像提示写在 **stderr**，PowerShell 直接 `flutter ... 2>&1` 时会当成错误记录显示。脚本已用 `_flutter_ps_helpers.ps1` 合并为普通文本，镜像提示以灰色 `(info)` 行显示。
2. **乱码**：终端代码页与 Flutter UTF-8 输出不一致。脚本开头会尝试切到 UTF-8（`chcp 65001`）；若仍乱码，可在 Cursor 设置 `terminal.integrated.defaultProfile.windows` 使用 Windows Terminal，或忽略仅影响美观的版本号行。

`=== Summary: OK=6 FAIL=0 ===` 即表示检查通过。

---

## 相关文档

- [WEB-SETUP-CHECKLIST.md](WEB-SETUP-CHECKLIST.md) — U2、一键检查  
- [ANDROID-SETUP-CHECKLIST.md](ANDROID-SETUP-CHECKLIST.md) — `flutter doctor`、设备检查  
- [README.md](../README.md) — 常见问题  
