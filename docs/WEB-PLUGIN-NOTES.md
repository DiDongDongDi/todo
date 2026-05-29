# Web 插件与能力说明（A2）

## 总体

Flutter Web 将应用编译为 **HTML + Canvas/WebGL + JS**，多数业务逻辑与移动端共用同一套 Dart 代码；部分插件在 Web 上行为不同或不可用。

---

## shared_preferences

- **Web：** 使用浏览器 `localStorage`
- **本项目的本地任务数据：** 可正常读写
- **注意：** 清除浏览器站点数据会清空任务

---

## speech_to_text

- **Web：** 依赖浏览器 **Web Speech API** 与麦克风权限
- **现状：** 部分浏览器/环境支持不完整；Chrome 桌面版通常可用，但不如 Android 稳定
- **建议：** Web 上优先测文字录入；语音以 Android 真机为准

---

## image_picker

- **Web：** 使用 `<input type="file">` 选择图片，**不能**像手机一样访问完整相册 API
- **收集 Tab：** 点选图片可用；粘贴行为因浏览器而异

---

## connectivity_plus / supabase_flutter

- **Web：** 需网络；Supabase 需配置 CORS（在 Supabase Dashboard 允许你的 Web 来源）
- **本地开发：** `http://localhost:*` 一般需在 Supabase 项目 URL 配置中加入

---

## 手势与交互

| 手势（移动端） | Web 近似方式 |
|----------------|--------------|
| 上划保存 | 鼠标拖拽向上 / 后续可做按钮兜底 |
| 左滑 / 右滑 | 鼠标拖拽 / 键盘 `←` `→` |
| 上划 / 下划切卡 | 键盘 `↑` `↓` |
| 触觉反馈 | 无 |

详见 [UX-GESTURES.md](UX-GESTURES.md) 与 [WEB-LIMITATIONS.md](WEB-LIMITATIONS.md)。

---

## 无需额外 Web 配置的插件

- `go_router`、`flutter_riverpod`、`uuid`、`intl` — 纯 Dart / 通用嵌入
