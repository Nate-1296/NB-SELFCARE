package com.nb.selfcare

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.SpeechRecognizer
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import com.nb.selfcare.health.HealthConnectBridge
import com.nb.selfcare.notifications.FastingNotifier
import com.nb.selfcare.notifications.MovementNudgeWorker
import com.nb.selfcare.notifications.NotificationChannels
import com.nb.selfcare.notifications.ReminderScheduler
import com.nb.selfcare.notifications.ReminderSpec
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

/**
 * Puente nativo de NB Selfcare: Health Connect, permisos del sistema y
 * notificaciones locales. Ningún canal habla con servidores remotos.
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val HEALTH_CHANNEL = "com.nb.selfcare/health_connect"
        private const val SYSTEM_CHANNEL = "com.nb.selfcare/system"
        private const val NOTIFICATIONS_CHANNEL = "com.nb.selfcare/notifications"
    }

    private lateinit var health: HealthConnectBridge
    private var pendingHealthResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    /** Acción pendiente para Flutter cuando Health Connect abre la política de privacidad. */
    private var pendingLaunchAction: String? = null

    private val healthPermissionLauncher: ActivityResultLauncher<Set<String>> =
        registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            pendingHealthResult?.success(granted.containsAll(HealthConnectBridge.ALL_PERMISSIONS))
            pendingHealthResult = null
        }

    private val runtimePermissionLauncher: ActivityResultLauncher<String> =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureLaunchAction(intent)
        health = HealthConnectBridge(applicationContext)
        NotificationChannels.ensure(applicationContext)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchAction(intent)
    }

    private fun captureLaunchAction(intent: Intent?) {
        when (intent?.action) {
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
            "android.intent.action.VIEW_PERMISSION_USAGE",
            -> pendingLaunchAction = "privacy_policy"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, HEALTH_CHANNEL).setMethodCallHandler(::onHealthCall)
        MethodChannel(messenger, SYSTEM_CHANNEL).setMethodCallHandler(::onSystemCall)
        MethodChannel(messenger, NOTIFICATIONS_CHANNEL).setMethodCallHandler(::onNotificationsCall)
    }

    private fun onHealthCall(call: MethodCall, result: MethodChannel.Result) {
        if (!::health.isInitialized) health = HealthConnectBridge(applicationContext)
        when (call.method) {
            "availability" -> result.success(health.availability())
            "hasPermissions" -> launchSafely(result) { health.hasAllPermissions() }
            "requestPermissions" -> {
                if (health.availability() != "available") {
                    result.success(false)
                    return
                }
                pendingHealthResult?.success(false)
                pendingHealthResult = result
                lifecycleScope.launch { health.requestPermissions(healthPermissionLauncher) }
            }
            "supportsBackgroundReads" -> launchSafely(result) { health.supportsBackgroundReads() }
            "hasBackgroundReadPermission" -> launchSafely(result) { health.hasBackgroundReadPermission() }
            "readDailyActivity" -> launchSafely(result) {
                health.readDailyActivity(call.argument<String>("dateKey")!!)
            }
            "writeWeight" -> launchSafely(result) {
                health.writeWeight(
                    weightKg = call.argument<Double>("weightKg")!!,
                    bodyFatPercent = call.argument<Double>("bodyFatPercentage"),
                    epochMillis = call.argument<Number>("timestampEpochMs")!!.toLong(),
                    fromScale = call.argument<Boolean>("fromScale") ?: false,
                )
            }
            "writeHydration" -> launchSafely(result) {
                health.writeHydration(
                    volumeMl = call.argument<Int>("amountMl")!!,
                    epochMillis = call.argument<Number>("timestampEpochMs")!!.toLong(),
                )
            }
            "openSettings" -> result.success(openHealthConnectSettings())
            else -> result.notImplemented()
        }
    }

    private fun onSystemCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> result.success(isGranted(call.argument<String>("permission")!!))
            "requestPermission" -> {
                val permission = call.argument<String>("permission")!!
                when {
                    permission == Manifest.permission.SCHEDULE_EXACT_ALARM -> result.success(openExactAlarmSettings())
                    isGranted(permission) -> result.success(true)
                    else -> {
                        pendingPermissionResult?.success(false)
                        pendingPermissionResult = result
                        runtimePermissionLauncher.launch(permission)
                    }
                }
            }
            "openAppSettings" -> result.success(openAppSettings())
            "consumeLaunchAction" -> {
                result.success(pendingLaunchAction)
                pendingLaunchAction = null
            }
            "isOnDeviceSpeechAvailable" -> result.success(
                Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(this),
            )
            else -> result.notImplemented()
        }
    }

    private fun onNotificationsCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showFastingTimer" -> {
                FastingNotifier(applicationContext).start(
                    startedAtMillis = call.argument<Number>("startedAtEpochMs")!!.toLong(),
                    targetHours = call.argument<Int>("targetHours")!!,
                    protocol = call.argument<String>("protocol")!!,
                )
                result.success(true)
            }
            "cancelFastingTimer" -> {
                FastingNotifier(applicationContext).stop()
                result.success(true)
            }
            "setReminders" -> {
                val specs = (call.argument<List<Map<*, *>>>("reminders") ?: emptyList()).map(ReminderSpec::fromMap)
                ReminderScheduler(applicationContext).replaceAll(specs)
                result.success(true)
            }
            "setMovementNudges" -> {
                if (call.argument<Boolean>("enabled") == true) {
                    MovementNudgeWorker.enable(
                        applicationContext,
                        startMinutes = call.argument<Int>("startMinutes") ?: (9 * 60),
                        endMinutes = call.argument<Int>("endMinutes") ?: (21 * 60),
                    )
                } else {
                    MovementNudgeWorker.disable(applicationContext)
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** Ejecuta una operación suspendida y responde siempre, aunque falle. */
    private fun launchSafely(result: MethodChannel.Result, block: suspend () -> Any?) {
        lifecycleScope.launch {
            try {
                result.success(block())
            } catch (error: Exception) {
                result.error("health_connect_error", error.message, null)
            }
        }
    }

    private fun isGranted(permission: String): Boolean = when (permission) {
        Manifest.permission.SCHEDULE_EXACT_ALARM ->
            Build.VERSION.SDK_INT < 31 || getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() == true
        Manifest.permission.POST_NOTIFICATIONS ->
            Build.VERSION.SDK_INT < 33 || hasRuntimePermission(permission)
        else -> hasRuntimePermission(permission)
    }

    private fun hasRuntimePermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun openExactAlarmSettings(): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        return startSafely(
            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.fromParts("package", packageName, null)),
        )
    }

    private fun openHealthConnectSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= 34) {
            Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS")
                .putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
        } else {
            Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
        }
        return startSafely(intent) || openAppSettings()
    }

    private fun openAppSettings(): Boolean = startSafely(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)),
    )

    private fun startSafely(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}
