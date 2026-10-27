package com.nb.selfcare.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.nb.selfcare.MainActivity

/** Canales de notificación de la app. Todos son locales: no hay push remoto. */
object NotificationChannels {
    const val FASTING = "fasting_timer"
    const val REMINDERS = "habit_reminders"
    const val MOVEMENT = "movement_nudges"

    fun ensure(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannels(
            listOf(
                NotificationChannel(FASTING, "Cronómetro de ayuno", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Tiempo de ayuno en curso en la pantalla de bloqueo."
                    setShowBadge(false)
                },
                NotificationChannel(REMINDERS, "Recordatorios de hábitos", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Pesaje, hidratación, ventana de comidas y diario."
                },
                NotificationChannel(MOVEMENT, "Pausas activas", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Invitaciones a moverte tras mucho tiempo sentado."
                },
            ),
        )
    }

    /** Abre la app (o la trae al frente) al tocar una notificación. */
    fun openAppIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
