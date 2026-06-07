# 路线图

## Phase 0 — 文档与脚手架

**目标：** 固化产品共识，搭建可运行的 Flutter 空壳。

### 交付物

- [x] `docs/PRODUCT.md`
- [x] `docs/UX-GESTURES.md`
- [x] `docs/ARCHITECTURE.md`
- [x] `docs/ROADMAP.md`
- [x] `README.md`、`.gitignore`
- [x] Flutter 多平台工程 `app/`
- [x] 底部 Tab 壳层 + 基础主题

### 验收标准

- `flutter pub get` 无错误
- `flutter run` 可启动，显示收集/处理双 Tab

---

## Phase 1 — 本地核心

**目标：** 离线可用的完整双 Tab 体验。

### 功能

- Drift 数据库 + TaskRepository
- 共享 `BigTaskCard` + `SwipeableCard`
- **收集 Tab：** 文字录入、上划保存、空白拦截、保存提示
- **处理 Tab：** inbox 卡片栈、上下切卡、左滑回收站、右滑归档、内联编辑
- 归档 / 回收站查看与恢复（设置入口）
- 处理清零环 + streak 本地统计
- 多模态：贴图、录音（`record` + 云端转写，见 [STT-SETUP.md](STT-SETUP.md)）

### 验收标准

- [ ] 收集页上划保存后，处理 Tab 可见该任务
- [ ] 处理页左滑 → 回收站可恢复
- [ ] 处理页右滑 → 归档可查看
- [ ] 离线重启数据不丢
- [ ] 空白上划有回弹提示

---

## Phase 2 — 同步与账号

**目标：** 多设备数据一致。

### 功能

- Supabase 项目 + migrations
- Auth（Email / OAuth）
- tasks 表 RLS + operations 同步表
- Storage 上传图片/音频
- SyncEngine：push/pull + LWW 合并
- Edge Function `transcribe` + 客户端转写队列（pending → done）

### 验收标准

- [ ] 登录后手机收集 → 桌面处理 Tab 5 秒内可见
- [ ] 离线编辑 → 联网后自动同步
- [ ] 两设备同时改同一任务，不丢数据（LWW）
- [ ] 附件跨设备可访问

---

## Phase 3 — 体验打磨

### 功能

- 卡片滑出动效精修、haptic
- 撤销 Snackbar
- 首次手势引导
- 桌面快捷键
- Web 响应式布局

### 验收标准

- [ ] 主要手势均有 haptic（移动端）
- [ ] 左右滑可 3 秒内撤销
- [ ] macOS/Windows 快捷键可用

---

## Phase 4 — 增强（可选）

- 推送提醒
- 自然语言日期（「明天下午」）
- iOS/Android Widget 快速录入
- 协作列表

---

## 里程碑时间（参考）

| Phase | 预估 |
|-------|------|
| 0 | 1–2 天 |
| 1 | 1–2 周 |
| 2 | 1–2 周 |
| 3 | 持续 |
| 4 | 按需 |
