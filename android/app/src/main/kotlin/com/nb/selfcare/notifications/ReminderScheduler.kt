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
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId

/** Recordatorio local programado (docs/07 §1.2). */
data class ReminderSpec(
    val id: Int,
    val title: String,
    val body: String,
    /** Minutos desde medianoche de la primera aparición del día. */
    val minutesOfDay: Int,
    /** Bit 0 = lunes … bit 6 = domingo. */
    val daysMask: Int,
    /** Si existe, se repite cada N minutos hasta [windowEndMinutes] (hidratación). */
    val intervalMinutes: Int?,
    val windowEndMinutes: Int,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("title", title)
        .put("body", body)
        .put("minutesOfDay", minutesOfDay)
        .put("daysMask", daysMask)
        .put("intervalMinutes", intervalMinutes ?: JSONObject.NULL)
        .put("windowEndMinutes", windowEndMinutes)

    companion object {
        fun fromJson(json: JSONObject) = ReminderSpec(
            id = json.getInt("id"),
            title = json.getString("title"),
            body = json.getString("body"),
            minutesOfDay = json.getInt("minutesOfDay"),
            daysMask = json.getInt("daysMask"),
            intervalMinutes = if (json.isNull("intervalMinutes")) null else json.getInt("intervalMinutes"),
            windowEndMinutes = json.optInt("windowEndMinutes", 21 * 60),
        )

        fun fromMap(map: Map<*, *>) = ReminderSpec(
            id = (map["id"] as Number).toInt(),
            title = map["title"] as String,
            body = map["body"] as String,
            minutesOfDay = (map["minutesOfDay"] as Number).toInt(),
            daysMask = (map["daysMask"] as Number).toInt(),
            intervalMinutes = (map["intervalMinutes"] as Number?)?.toInt(),
            windowEndMinutes = (map["windowEndMinutes"] as Number?)?.toInt() ?: (21 * 60),
        )
    }

    /** Siguiente aparición estrictamente posterior a [after], o `null` si no hay días activos. */
    fun nextOccurrence(after: LocalDateTime): LocalDateTime? {
        if (daysMask and 0x7F == 0) return null
        for (dayOffset in 0..7) {
            val date = after.toLocalDate().plusDays(dayOffset.toLong())
            val weekdayBit = 1 shl (date.dayOfWeek.value - 1)
            if (daysMask and weekdayBit == 0) continue

            val slots = if (intervalMinutes != null && intervalMinutes > 0) {
                generateSequence(minutesOfDay) { it + intervalMinutes }.takeWhile { it <= windowEndMinutes }
            } else {
                sequenceOf(minutesOfDay)
            }
            val candidate = slots
                .map { date.atStartOfDay().plusMinutes(it.toLong()) }
                .firstOrNull { it.isAfter(after) }
            if (candidate != null) return candidate
        }
        return null
    }
}

/**
 * Programa los recordatorios con `AlarmManager`: exactos si el usuario concedió
 * SCHEDULE_EXACT_ALARM y, si no, inexactos (degradación elegante, docs/07 §1.1).
 * La lista se guarda localmente para reprogramarla tras un reinicio.
 */
class ReminderScheduler(private val context: Context) {

    companion object {
        private const val PREFS = "nb_reminders"
        private const val KEY_SPECS = "specs"
        const val EXTRA_ID = "reminder_id"
    }

    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(AlarmManager::class.java)

    fun replaceAll(specs: List<ReminderSpec>) {
        stored().forEach { cancel(it.id) }
        val json = JSONArray().apply { specs.forEach { put(it.toJson()) } }
        prefs.edit().putString(KEY_SPECS, json.toString()).apply()
        specs.forEach { scheduleNext(it) }
    }

    fun rescheduleAll() = stored().forEach { scheduleNext(it) }

    fun stored(): List<ReminderSpec> {
        val raw = prefs.getString(KEY_SPECS, null) ?: return emptyList()
        val array = JSONArray(raw)
        return (0 until array.length()).map { ReminderSpec.fromJson(array.getJSONObject(it)) }
    }

    fun scheduleNext(spec: ReminderSpec) {
        val next = spec.nextOccurrence(LocalDateTime.now()) ?: return
        val triggerAt = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val intent = pendingIntent(spec.id)
        val manager = alarms ?: return
        if (Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()) {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, intent)
        } else {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, intent)
        }
    }

    private fun cancel(id: Int) {
        alarms?.cancel(pendingIntent(id))
    }

    private fun pendingIntent(id: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        6000 + id,
        Intent(context, ReminderReceiver::class.java).putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

/** Muestra el recordatorio y programa su siguiente aparición. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(ReminderScheduler.EXTRA_ID, -1)
        val scheduler = ReminderScheduler(context)
        val spec = scheduler.stored().firstOrNull { it.id == id } ?: return

        val canNotify = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (canNotify) {
            NotificationChannels.ensure(context)
            val notification = NotificationCompat.Builder(context, NotificationChannels.REMINDERS)
                .setSmallIcon(R.drawable.ic_stat_reminder)
                .setContentTitle(spec.title)
                .setContentText(spec.body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(spec.body))
                .setAutoCancel(true)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setContentIntent(NotificationChannels.openAppIntent(context, 7000 + id))
                .build()
            NotificationManagerCompat.from(context).notify(7000 + id, notification)
        }
        scheduler.scheduleNext(spec)
    }
}
