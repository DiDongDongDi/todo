# Android 插件配置说明（A2）

## record（收集 Tab 录音）

- **权限：** `RECORD_AUDIO`（已在 `app/android/app/src/main/AndroidManifest.xml` 声明）
- **格式：** m4a / AAC，保存到应用文档目录 `attachments/`
- **运行时：** 首次录音时请求麦克风权限；Web 端暂不支持（收集页隐藏麦克风）

## image_picker

- **权限：** `READ_MEDIA_IMAGES`（API 33+）、`READ_EXTERNAL_STORAGE`（API ≤32）（已声明）
- **用法：** 收集 Tab 使用 `ImageSource.gallery`，无需 `CAMERA` 权限
- **运行时：** Android 13+ 可能使用系统 Photo Picker，部分机型无需额外权限弹窗

## connectivity_plus / supabase_flutter

- **权限：** `INTERNET`（已声明）
- 无额外 Gradle 配置

## 无需改动的插件

- `shared_preferences`、`path_provider`、`sqlite3_flutter_libs` — 标准嵌入，无额外 manifest

## 收集音效（系统通知音库）

- **Android：** 通过 `MainActivity` 的 MethodChannel（`com.todo.app/notification_sound`）调用 `RingtoneManager.ACTION_RINGTONE_PICKER` 打开系统通知音选择器，并用 `RingtoneManager.getRingtone()` 播放
- **权限：** 无需额外 manifest 权限（读取/播放系统铃声 URI）
- **其他平台：** 暂不支持系统通知音库，设置页会提示仅保留震动

## 语音转写

- 不使用系统 STT；云端转写见 [STT-SETUP.md](STT-SETUP.md)
