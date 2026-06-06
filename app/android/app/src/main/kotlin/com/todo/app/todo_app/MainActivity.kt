package com.todo.app.todo_app

import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.todo.app/notification_sound"
    private var pendingPickResult: MethodChannel.Result? = null
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
    }
}
