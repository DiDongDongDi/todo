# Web 环境局限说明（A6）

日常开发推荐 Chrome，但以下差异**属正常**，不要以 Web 手感等同于真机。

## 交互与手势

- **划动**依赖鼠标拖拽或触控板，没有手机上的跟手惯性与边缘手势
- **无触觉反馈（haptic）**
- 收集 Tab「上划保存」在窄窗口或触摸板上可能不如手机直观

**对策：** 处理 Tab 使用键盘 `←` `→` `↑` `↓`（见 [UX-GESTURES.md](UX-GESTURES.md)）；手势打磨用 [Android 真机清单](ANDROID-SETUP-CHECKLIST.md)。

## 多模态录入

| 能力 | Web |
|------|-----|
| 文字 | ✓ 完整 |
| 录音 + 云端转写 | ✗ 第一版不支持（移动端可用） |
| 相册选图 | △ 文件选择器，非完整相册 |

## 性能与调试

- 首次 `flutter run -d chrome` 需编译 Web，比热重载慢一次
- 复杂动画在低端机器上可能略卡
- 用 Chrome **F12 → Console** 看报错；**Network** 看 Supabase 请求

## 同步（Supabase）

- 需浏览器能访问 Supabase
- 若登录/同步失败，检查 Supabase **Authentication URL** 与 **CORS** 是否包含 `http://localhost`

## 适合在 Web 做的

- UI 布局、主题、文案
- 状态管理、路由、本地 CRUD
- 业务逻辑与单元测试
- 快速热重载迭代

## 不适合仅在 Web 验收的

- 划动是否「上瘾」、是否顺手
- 语音录入稳定性
- 多设备真机同步后的手感
