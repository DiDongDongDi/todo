# Android 插件配置说明（A2）

## speech_to_text

- **权限：** `RECORD_AUDIO`（已在 `app/android/app/src/main/AndroidManifest.xml` 声明）
- **queries：** `android.speech.RecognitionService`（Android 11+ 可见性，已声明）
- **运行时：** 插件会在首次使用时请求麦克风权限；需在代码中处理 `SpeechToText.initialize()` 返回 false 的情况（`collect_screen.dart` 已调用）
- **依赖：** 设备需安装 Google 语音服务或厂商自带语音识别（国内部分机型可用系统语音）

## image_picker

- **权限：** `READ_MEDIA_IMAGES`（API 33+）、`READ_EXTERNAL_STORAGE`（API ≤32）（已声明）
- **用法：** 收集 Tab 使用 `ImageSource.gallery`，无需 `CAMERA` 权限
- **运行时：** Android 13+ 可能使用系统 Photo Picker，部分机型无需额外权限弹窗

## connectivity_plus / supabase_flutter

- **权限：** `INTERNET`（已声明）
- 无额外 Gradle 配置

## 无需改动的插件

- `shared_preferences`、`path_provider`、`sqlite3_flutter_libs` — 标准嵌入，无额外 manifest
