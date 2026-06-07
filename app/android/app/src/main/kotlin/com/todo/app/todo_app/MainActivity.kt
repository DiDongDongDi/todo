package com.todo.app.todo_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.speech.RecognizerIntent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.todo.app/notification_sound"
    private val speechChannelName = "com.todo.app/speech_intent"
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var pendingSpeechPrompt: String? = null
    private var playingRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)

                    "getDefaultUri" -> {
                        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        result.success(uri?.toString())
                    }

                    "getTitle" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString.isNullOrEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val ringtone = RingtoneManager.getRingtone(this, Uri.parse(uriString))
                        result.success(ringtone?.getTitle(this))
                    }

                    "play" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString.isNullOrEmpty()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        playRingtone(Uri.parse(uriString))
                        result.success(null)
                    }

                    "stop" -> {
                        stopRingtone()
                        result.success(null)
                    }

                    "pick" -> {
                        if (pendingPickResult != null) {
                            result.error("busy", "Picker already open", null)
                            return@setMethodCallHandler
                        }
                        pendingPickResult = result
                        val existingUri = call.argument<String>("existingUri")
                        val defaultUri =
                            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "选择通知音")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, defaultUri)
                            if (!existingUri.isNullOrEmpty()) {
                                putExtra(
                                    RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                                    Uri.parse(existingUri),
                                )
                            }
                        }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, pickRingtoneRequestCode)
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speechChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(isSpeechIntentAvailable())

                    "recognize" -> {
                        if (pendingSpeechResult != null) {
                            result.error("busy", "Speech already in progress", null)
                            return@setMethodCallHandler
                        }
                        if (!isSpeechIntentAvailable()) {
                            result.error("unavailable", "Speech recognition not available", null)
                            return@setMethodCallHandler
                        }
                        val prompt = call.argument<String>("prompt") ?: "请说话…"
                        pendingSpeechResult = result
                        pendingSpeechPrompt = prompt
                        if (!hasRecordAudioPermission()) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                recordAudioRequestCode,
                            )
                            return@setMethodCallHandler
                        }
                        launchSpeechRecognizer(prompt)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasRecordAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isSpeechIntentAvailable(): Boolean {
        return buildSpeechIntent("test") != null
    }

    private fun buildSpeechIntent(prompt: String): Intent? {
        val base = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        // 小米等机型优先走 Google 语音（若已安装），避免系统语音引擎未授权报错 (2)
        val googlePackage = "com.google.android.googlequicksearchbox"
        if (isIntentResolvable(base, googlePackage)) {
            return Intent(base).setPackage(googlePackage)
        }

        return if (isIntentResolvable(base, null)) base else null
    }

    private fun isIntentResolvable(intent: Intent, packageName: String?): Boolean {
        val probe = if (packageName != null) {
            Intent(intent).setPackage(packageName)
        } else {
            intent
        }
        return packageManager
            .queryIntentActivities(probe, PackageManager.MATCH_DEFAULT_ONLY)
            .isNotEmpty()
    }

    private fun launchSpeechRecognizer(prompt: String) {
        val intent = buildSpeechIntent(prompt)
        if (intent == null) {
            val speechResult = pendingSpeechResult
            pendingSpeechResult = null
            pendingSpeechPrompt = null
            speechResult?.error("unavailable", "Speech recognition not available", null)
            return
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, speechRequestCode)
        } catch (_: android.content.ActivityNotFoundException) {
            val speechResult = pendingSpeechResult
            pendingSpeechResult = null
            pendingSpeechPrompt = null
            speechResult?.error("unavailable", "Speech recognition not available", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == recordAudioRequestCode) {
            val speechResult = pendingSpeechResult
            val prompt = pendingSpeechPrompt
            pendingSpeechPrompt = null

            if (speechResult != null) {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                if (granted) {
                    launchSpeechRecognizer(prompt ?: "请说话…")
                } else {
                    pendingSpeechResult = null
                    speechResult.error("permission_denied", "Microphone permission denied", null)
                }
            }
            return
        }

        @Suppress("DEPRECATION")
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == pickRingtoneRequestCode) {
            val result = pendingPickResult
            pendingPickResult = null

            if (result != null) {
                if (resultCode != RESULT_OK) {
                    result.success(null)
                } else {
                    val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                    }

                    if (uri == null) {
                        result.success(
                            mapOf(
                                "enabled" to false,
                            ),
                        )
                    } else {
                        val title = RingtoneManager.getRingtone(this, uri)?.getTitle(this) ?: "通知音"
                        result.success(
                            mapOf(
                                "enabled" to true,
                                "uri" to uri.toString(),
                                "title" to title,
                            ),
                        )
                    }
                }
            }
            return
        }

        if (requestCode == speechRequestCode) {
            val speechResult = pendingSpeechResult
            pendingSpeechResult = null

            if (speechResult != null) {
                if (resultCode == RESULT_OK && data != null) {
                    val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                    val text = matches?.firstOrNull()
                    speechResult.success(
                        mapOf(
                            "text" to text,
                            "cancelled" to false,
                            "engineFailed" to false,
                            "permissionDenied" to false,
                        ),
                    )
                } else if (resultCode == RESULT_CANCELED) {
                    speechResult.success(
                        mapOf(
                            "text" to null,
                            "cancelled" to true,
                            "engineFailed" to false,
                            "permissionDenied" to false,
                        ),
                    )
                } else {
                    // 小米「似乎出错了呢 (2)」等系统语音引擎错误
                    speechResult.success(
                        mapOf(
                            "text" to null,
                            "cancelled" to false,
                            "engineFailed" to true,
                            "permissionDenied" to false,
                            "resultCode" to resultCode,
                        ),
                    )
                }
            }
            return
        }

        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun playRingtone(uri: Uri) {
        stopRingtone()
        val ringtone = RingtoneManager.getRingtone(this, uri) ?: return
        playingRingtone = ringtone
        ringtone.play()
    }

    private fun stopRingtone() {
        playingRingtone?.stop()
        playingRingtone = null
    }

    companion object {
        private const val pickRingtoneRequestCode = 7412
        private const val speechRequestCode = 7413
        private const val recordAudioRequestCode = 7414
    }
}
