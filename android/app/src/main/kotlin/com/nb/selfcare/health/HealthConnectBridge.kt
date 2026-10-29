package com.nb.selfcare.health

import android.content.Context
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.feature.ExperimentalMindfulnessSessionApi
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
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

        /** Lectura de signos vitales: solo se pide la de los aparatos que la persona declara. */
        val VITAL_PERMISSIONS: Map<String, String> = mapOf(
            "blood_pressure" to HealthPermission.getReadPermission(BloodPressureRecord::class),
            "glucose" to HealthPermission.getReadPermission(BloodGlucoseRecord::class),
            "oxygen" to HealthPermission.getReadPermission(OxygenSaturationRecord::class),
            "temperature" to HealthPermission.getReadPermission(BodyTemperatureRecord::class),
        )

        /** Escritura de sesiones de respiración (Android 16 / proveedor actualizado). */
        const val MINDFULNESS_WRITE_PERMISSION = "android.permission.health.WRITE_MINDFULNESS"

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

    /**
     * Incluye la lectura en segundo plano y las sesiones de respiración solo si
     * el proveedor las soporta. Devuelve el conjunto que se considera "concedido".
     */
    suspend fun requestPermissions(launcher: ActivityResultLauncher<Set<String>>): Set<String> {
        val permissions = buildSet {
            addAll(ALL_PERMISSIONS)
            if (supportsBackgroundReads()) add(HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND)
            if (supportsMindfulness()) add(MINDFULNESS_WRITE_PERMISSION)
        }
        launcher.launch(permissions)
        return ALL_PERMISSIONS
    }

    /** Pide la lectura de los signos vitales indicados ("blood_pressure", "glucose"…). */
    fun requestVitalPermissions(launcher: ActivityResultLauncher<Set<String>>, kinds: List<String>): Set<String> {
        val permissions = kinds.mapNotNull { VITAL_PERMISSIONS[it] }.toSet()
        if (permissions.isNotEmpty()) launcher.launch(permissions)
        return permissions
    }

    @OptIn(ExperimentalMindfulnessSessionApi::class)
    suspend fun supportsMindfulness(): Boolean {
        val client = clientOrNull() ?: return false
        return client.features.getFeatureStatus(
            HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION,
        ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
    }

    /**
     * Lecturas de signos vitales desde [sinceMillis] para los tipos concedidos.
     * Cada lectura lleva su id de Health Connect para no duplicarla.
     */
    suspend fun readVitals(kinds: List<String>, sinceMillis: Long): List<Map<String, Any?>> {
        val client = clientOrNull() ?: return emptyList()
        val granted = client.permissionController.getGrantedPermissions()
        val range = TimeRangeFilter.between(Instant.ofEpochMilli(sinceMillis), Instant.now())
        val readings = mutableListOf<Map<String, Any?>>()
        fun allowed(kind: String) = kind in kinds && VITAL_PERMISSIONS[kind] in granted

        if (allowed("blood_pressure")) {
            client.readRecords(ReadRecordsRequest(BloodPressureRecord::class, range)).records.forEach {
                readings += mapOf(
                    "id" to it.metadata.id,
                    "kind" to "blood_pressure",
                    "time" to it.time.toEpochMilli(),
                    "primary" to it.systolic.inMillimetersOfMercury,
                    "secondary" to it.diastolic.inMillimetersOfMercury,
                )
            }
        }
        if (allowed("glucose")) {
            client.readRecords(ReadRecordsRequest(BloodGlucoseRecord::class, range)).records.forEach {
                val context = when (it.relationToMeal) {
                    BloodGlucoseRecord.RELATION_TO_MEAL_FASTING -> "fasting"
                    BloodGlucoseRecord.RELATION_TO_MEAL_AFTER_MEAL -> "after_meal"
                    else -> "random"
                }
                readings += mapOf(
                    "id" to it.metadata.id,
                    "kind" to "glucose",
                    "time" to it.time.toEpochMilli(),
                    "primary" to it.level.inMilligramsPerDeciliter,
                    "context" to context,
                )
            }
        }
        if (allowed("oxygen")) {
            client.readRecords(ReadRecordsRequest(OxygenSaturationRecord::class, range)).records.forEach {
                readings += mapOf(
                    "id" to it.metadata.id,
                    "kind" to "oxygen",
                    "time" to it.time.toEpochMilli(),
                    "primary" to it.percentage.value,
                )
            }
        }
        if (allowed("temperature")) {
            client.readRecords(ReadRecordsRequest(BodyTemperatureRecord::class, range)).records.forEach {
                readings += mapOf(
                    "id" to it.metadata.id,
                    "kind" to "temperature",
                    "time" to it.time.toEpochMilli(),
                    "primary" to it.temperature.inCelsius,
                )
            }
        }
        return readings
    }

    /** Guarda una sesión de respiración guiada como sesión de mindfulness. */
    @OptIn(ExperimentalMindfulnessSessionApi::class)
    suspend fun writeMindfulness(startMillis: Long, endMillis: Long, title: String): Boolean {
        val client = clientOrNull() ?: return false
        if (!supportsMindfulness()) return false
        if (MINDFULNESS_WRITE_PERMISSION !in client.permissionController.getGrantedPermissions()) return false
        val start = Instant.ofEpochMilli(startMillis)
        val end = Instant.ofEpochMilli(endMillis)
        client.insertRecords(
            listOf(
                MindfulnessSessionRecord(
                    startTime = start,
                    startZoneOffset = offsetAt(start),
                    endTime = end,
                    endZoneOffset = offsetAt(end),
                    metadata = Metadata.manualEntry(),
                    mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_BREATHING,
                    title = title,
                ),
            ),
        )
        return true
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
        var wakeMinutes: Int? = null
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
                val wake = sessions.maxOf { it.endTime }.atZone(zone).toLocalTime()
                wakeMinutes = wake.hour * 60 + wake.minute
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
            "wakeMinutes" to wakeMinutes,
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
