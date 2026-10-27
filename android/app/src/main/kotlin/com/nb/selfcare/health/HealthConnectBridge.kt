package com.nb.selfcare.health

import android.content.Context
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Percentage
import androidx.health.connect.client.units.Volume
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Acceso a Health Connect con el SDK oficial (androidx.health.connect).
 *
 * Todas las lecturas y escrituras ocurren en el dispositivo: Health Connect es
 * un almacén local del sistema, no un servicio en la nube.
 */
class HealthConnectBridge(private val context: Context) {

    companion object {
        const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"

        val READ_PERMISSIONS: Set<String> = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(RestingHeartRateRecord::class),
            HealthPermission.getReadPermission(WeightRecord::class),
            HealthPermission.getReadPermission(BodyFatRecord::class),
            HealthPermission.getReadPermission(HydrationRecord::class),
        )

        val WRITE_PERMISSIONS: Set<String> = setOf(
            HealthPermission.getWritePermission(WeightRecord::class),
            HealthPermission.getWritePermission(BodyFatRecord::class),
            HealthPermission.getWritePermission(HydrationRecord::class),
        )

        val ALL_PERMISSIONS: Set<String> = READ_PERMISSIONS + WRITE_PERMISSIONS

        /** Ventana de búsqueda del sueño de una fecha: sesiones que terminan ese día. */
        private val SLEEP_LOOKBACK: Duration = Duration.ofHours(18)
    }

    /** "available" | "update_required" | "not_installed" | "unsupported". */
    fun availability(): String = when (HealthConnectClient.getSdkStatus(context, PROVIDER_PACKAGE)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
        else -> if (android.os.Build.VERSION.SDK_INT >= 34) "unsupported" else "not_installed"
    }

    private fun clientOrNull(): HealthConnectClient? =
        if (HealthConnectClient.getSdkStatus(context, PROVIDER_PACKAGE) == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(context)
        } else {
            null
        }

    suspend fun grantedPermissions(): Set<String> =
        clientOrNull()?.permissionController?.getGrantedPermissions() ?: emptySet()

    suspend fun hasAllPermissions(): Boolean = grantedPermissions().containsAll(ALL_PERMISSIONS)

    /** Incluye la lectura en segundo plano solo si el proveedor la soporta. */
    suspend fun requestPermissions(launcher: ActivityResultLauncher<Set<String>>) {
        val permissions = if (supportsBackgroundReads()) {
            ALL_PERMISSIONS + HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND
        } else {
            ALL_PERMISSIONS
        }
        launcher.launch(permissions)
    }

    suspend fun hasBackgroundReadPermission(): Boolean =
        HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND in grantedPermissions()

    /** Lectura en segundo plano (Android 15+ / proveedor actualizado) para el aviso de sedentarismo. */
    suspend fun supportsBackgroundReads(): Boolean {
        val client = clientOrNull() ?: return false
        return client.features.getFeatureStatus(
            HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND,
        ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
    }

    /**
     * Resumen de actividad de un día local: pasos del día, sueño de la noche que
     * termina ese día (con fases si la fuente las aporta) y FC en reposo.
     */
    suspend fun readDailyActivity(dateKey: String): Map<String, Any?>? {
        val client = clientOrNull() ?: return null
        val granted = client.permissionController.getGrantedPermissions()
        val zone = ZoneId.systemDefault()
        val day = LocalDate.parse(dateKey)
        val start = day.atStartOfDay(zone).toInstant()
        val end = day.plusDays(1).atStartOfDay(zone).toInstant()

        var steps: Long? = null
        if (HealthPermission.getReadPermission(StepsRecord::class) in granted) {
            val result = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                ),
            )
            steps = result[StepsRecord.COUNT_TOTAL] ?: 0L
        }

        var sleepMinutes: Long? = null
        var deepMinutes = 0L
        var remMinutes = 0L
        if (HealthPermission.getReadPermission(SleepSessionRecord::class) in granted) {
            val sessions = client.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start.minus(SLEEP_LOOKBACK), end),
                ),
            ).records.filter { !it.endTime.isBefore(start) && it.endTime.isBefore(end) }
            if (sessions.isNotEmpty()) {
                sleepMinutes = sessions.sumOf { Duration.between(it.startTime, it.endTime).toMinutes() }
                for (stage in sessions.flatMap { it.stages }) {
                    val minutes = Duration.between(stage.startTime, stage.endTime).toMinutes()
                    when (stage.stage) {
                        SleepSessionRecord.STAGE_TYPE_DEEP -> deepMinutes += minutes
                        SleepSessionRecord.STAGE_TYPE_REM -> remMinutes += minutes
                    }
                }
            }
        }

        var restingHeartRate: Long? = null
        if (HealthPermission.getReadPermission(RestingHeartRateRecord::class) in granted) {
            restingHeartRate = client.readRecords(
                ReadRecordsRequest(
                    recordType = RestingHeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                ),
            ).records.maxByOrNull { it.time }?.beatsPerMinute
        }

        return mapOf(
            "steps" to steps,
            "sleepMinutes" to sleepMinutes,
            "deepMinutes" to deepMinutes,
            "remMinutes" to remMinutes,
            "restingHeartRate" to restingHeartRate,
        )
    }

    /** Pasos registrados entre dos instantes (aviso de sedentarismo). */
    suspend fun readStepsBetween(start: Instant, end: Instant): Long? {
        val client = clientOrNull() ?: return null
        val result = client.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end),
            ),
        )
        return result[StepsRecord.COUNT_TOTAL] ?: 0L
    }

    suspend fun writeWeight(
        weightKg: Double,
        bodyFatPercent: Double?,
        epochMillis: Long,
        fromScale: Boolean,
    ): Boolean {
        val client = clientOrNull() ?: return false
        val granted = client.permissionController.getGrantedPermissions()
        val time = Instant.ofEpochMilli(epochMillis)
        val offset = offsetAt(time)
        val metadata = if (fromScale) {
            Metadata.autoRecorded(Device(type = Device.TYPE_SCALE))
        } else {
            Metadata.manualEntry()
        }

        val records = buildList {
            if (HealthPermission.getWritePermission(WeightRecord::class) in granted) {
                add(WeightRecord(time = time, zoneOffset = offset, weight = Mass.kilograms(weightKg), metadata = metadata))
            }
            if (bodyFatPercent != null && HealthPermission.getWritePermission(BodyFatRecord::class) in granted) {
                add(BodyFatRecord(time = time, zoneOffset = offset, percentage = Percentage(bodyFatPercent), metadata = metadata))
            }
        }
        if (records.isEmpty()) return false
        client.insertRecords(records)
        return true
    }

    suspend fun writeHydration(volumeMl: Int, epochMillis: Long): Boolean {
        val client = clientOrNull() ?: return false
        val granted = client.permissionController.getGrantedPermissions()
        if (HealthPermission.getWritePermission(HydrationRecord::class) !in granted) return false
        val end = Instant.ofEpochMilli(epochMillis)
        val start = end.minusSeconds(60)
        client.insertRecords(
            listOf(
                HydrationRecord(
                    startTime = start,
                    startZoneOffset = offsetAt(start),
                    endTime = end,
                    endZoneOffset = offsetAt(end),
                    volume = Volume.milliliters(volumeMl.toDouble()),
                    metadata = Metadata.manualEntry(),
                ),
            ),
        )
        return true
    }

    private fun offsetAt(instant: Instant): ZoneOffset = ZoneId.systemDefault().rules.getOffset(instant)
}
