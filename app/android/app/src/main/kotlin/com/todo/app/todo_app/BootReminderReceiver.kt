package com.todo.app.todo_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Marks that a plan reminder sync should run after boot.
/// WorkManager periodic tasks and flutter_foreground_task autoRunOnBoot handle execution.
class BootReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        context
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.plan_reminder_boot_pending", true)
            .apply()
    }
}
