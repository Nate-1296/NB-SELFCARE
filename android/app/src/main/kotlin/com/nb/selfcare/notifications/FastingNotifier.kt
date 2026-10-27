package com.nb.selfcare.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.nb.selfcare.R
import java.text.DateFormat
import java.util.Date

/**
 * Cronómetro de ayuno en la pantalla de bloqueo (ADR-06).
 *
 * Usa `setUsesChronometer`: el sistema actualiza los segundos sin que la app
 * esté viva. En Android 16 se solicita la promoción a Live Update. El texto de
 * la fase metabólica se refresca con alarmas puntuales en cada transición.
 */
class FastingNotifier(private val context: Context) {

    companion object {
        private const val NOTIFICATION_ID = 4101
        private const val PREFS = "nb_fasting_timer"
        private const val KEY_STARTED = "started_at"
        private const val KEY_TARGET_HOURS = "target_hours"
        private const val KEY_PROTOCOL = "protocol"

        /** Extra de Android 16 (Notification.EXTRA_REQUEST_PROMOTED_ONGOING). */
        private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

        /** Límites de fase de docs/09 §1 (horas). */
        private val PHASE_BOUNDARIES = listOf(4, 12, 18, 24)
    }

    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun start(startedAtMillis: Long, targetHours: Int, protocol: String) {
        prefs.edit()
            .putLong(KEY_STARTED, startedAtMillis)
            .putInt(KEY_TARGET_HOURS, targetHours)
            .putString(KEY_PROTOCOL, protocol)
            .apply()
        post()
        schedulePhaseUpdates(startedAtMillis, targetHours)
    }

    fun stop() {
        prefs.edit().clear().apply()
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
        cancelPhaseUpdates()
    }

    /** Vuelve a publicar la notificación tras un reinicio o una transición de fase. */
    fun restore() {
        val started = prefs.getLong(KEY_STARTED, -1L)
        if (started <= 0L) return
        post()
        schedulePhaseUpdates(started, prefs.getInt(KEY_TARGET_HOURS, 16))
    }

    private fun post() {
        val started = prefs.getLong(KEY_STARTED, -1L)
        if (started <= 0L || !canNotify()) return
        val targetHours = prefs.getInt(KEY_TARGET_HOURS, 16)
        val protocol = prefs.getString(KEY_PROTOCOL, null) ?: "${targetHours}h"
        val elapsedHours = (System.currentTimeMillis() - started) / 3_600_000.0
        val goalAt = started + targetHours * 3_600_000L
        val goalText = if (elapsedHours >= targetHours) {
            "¡Meta de ${targetHours} h alcanzada!"
        } else {
            "Meta a las ${DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(goalAt))}"
        }

        val notification = NotificationCompat.Builder(context, NotificationChannels.FASTING)
            .setSmallIcon(R.drawable.ic_stat_fasting)
            .setContentTitle("Ayuno $protocol · ${phaseFor(elapsedHours)}")
            .setContentText(goalText)
            .setWhen(started)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(NotificationChannels.openAppIntent(context, NOTIFICATION_ID))
            .addExtras(android.os.Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
            .build()
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    private fun phaseFor(hours: Double): String = when {
        hours < 4 -> "Fase anabólica"
        hours < 12 -> "Glucogenólisis"
        hours < 18 -> "Quema de grasa"
        hours < 24 -> "Cetosis"
        else -> "Autofagia"
    }

    private fun schedulePhaseUpdates(startedAtMillis: Long, targetHours: Int) {
        cancelPhaseUpdates()
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val now = System.currentTimeMillis()
        (PHASE_BOUNDARIES + targetHours).distinct().forEachIndexed { index, hours ->
            val at = startedAtMillis + hours * 3_600_000L
            if (at > now) {
                alarms.set(AlarmManager.RTC, at, phaseIntent(index))
            }
        }
    }

    private fun cancelPhaseUpdates() {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        for (index in 0..PHASE_BOUNDARIES.size) {
            alarms.cancel(phaseIntent(index))
        }
    }

    private fun phaseIntent(index: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        5100 + index,
        Intent(context, FastingPhaseReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun canNotify(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
}

/** Refresca el texto de la fase metabólica en cada transición. */
class FastingPhaseReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        FastingNotifier(context).restore()
    }
}
