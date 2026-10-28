package com.nb.selfcare.notifications

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.nb.selfcare.R
import com.nb.selfcare.health.HealthConnectBridge
import java.time.Instant
import java.time.LocalTime
import java.util.concurrent.TimeUnit

/**
 * Pomodoro de sedentarismo (docs/07 §1.2): cada 15 min revisa, en el
 * dispositivo, los pasos de la última hora en Health Connect y, dentro del
 * horario activo, invita a una pausa de 2 minutos. Nunca regaña.
 */
class MovementNudgeWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    companion object {
        private const val WORK_NAME = "movement_nudges"
        private const val PREFS = "nb_movement_nudges"
        private const val KEY_START = "start_minutes"
        private const val KEY_END = "end_minutes"
        private const val KEY_LAST_NUDGE = "last_nudge"
        private const val NOTIFICATION_ID = 4201

        /** Ventana sin movimiento que dispara la invitación. */
        private const val SEDENTARY_WINDOW_MINUTES = 60L

        /** Por debajo de estos pasos en la ventana se considera tiempo sentado. */
        private const val SEDENTARY_STEP_THRESHOLD = 120L

        /** Separación mínima entre dos invitaciones. */
        private const val MIN_GAP_MINUTES = 90L

        fun enable(context: Context, startMinutes: Int, endMinutes: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putInt(KEY_START, startMinutes)
                .putInt(KEY_END, endMinutes)
                .apply()
            val request = PeriodicWorkRequestBuilder<MovementNudgeWorker>(15, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
        }

        fun disable(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }

    override suspend fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val nowMinutes = LocalTime.now().let { it.hour * 60 + it.minute }
        if (nowMinutes < prefs.getInt(KEY_START, 9 * 60) || nowMinutes >= prefs.getInt(KEY_END, 21 * 60)) {
            return Result.success()
        }

        val now = Instant.now()
        val lastNudge = Instant.ofEpochMilli(prefs.getLong(KEY_LAST_NUDGE, 0L))
        if (lastNudge.plusSeconds(MIN_GAP_MINUTES * 60).isAfter(now)) return Result.success()

        val bridge = HealthConnectBridge(applicationContext)
        if (!bridge.supportsBackgroundReads() || !bridge.hasBackgroundReadPermission()) {
            return Result.success()
        }
        val steps = runCatching {
            bridge.readStepsBetween(now.minusSeconds(SEDENTARY_WINDOW_MINUTES * 60), now)
        }.getOrNull() ?: return Result.success()
        if (steps >= SEDENTARY_STEP_THRESHOLD) return Result.success()

        val canNotify = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!canNotify) return Result.success()

        NotificationChannels.ensure(applicationContext)
        val notification = NotificationCompat.Builder(applicationContext, NotificationChannels.MOVEMENT)
            .setSmallIcon(R.drawable.ic_stat_walk)
            .setContentTitle("¿Una pausa activa de 2 minutos?")
            .setContentText("Estirar o caminar un poco ahora le sienta genial a tu espalda y a tu energía.")
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(NotificationChannels.openAppIntent(applicationContext, NOTIFICATION_ID))
            .build()
        NotificationManagerCompat.from(applicationContext).notify(NOTIFICATION_ID, notification)
        prefs.edit().putLong(KEY_LAST_NUDGE, now.toEpochMilli()).apply()
        return Result.success()
    }
}
