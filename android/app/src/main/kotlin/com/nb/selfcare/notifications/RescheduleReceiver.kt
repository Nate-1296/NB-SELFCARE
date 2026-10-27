package com.nb.selfcare.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Las alarmas de Android se pierden al reiniciar o al cambiar la hora: este
 * receptor vuelve a programar recordatorios y el cronómetro de ayuno.
 */
class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
            -> {
                NotificationChannels.ensure(context)
                ReminderScheduler(context).rescheduleAll()
                FastingNotifier(context).restore()
            }
        }
    }
}
