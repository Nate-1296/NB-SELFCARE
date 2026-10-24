package com.nb.selfcare

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val HEALTH_CHANNEL = "com.nb.selfcare/health_connect"
        private const val HC_PACKAGE = "com.google.android.apps.healthdata"

        private val HEALTH_PERMISSIONS = arrayOf(
            "android.permission.health.READ_WEIGHT",
            "android.permission.health.WRITE_WEIGHT",
            "android.permission.health.READ_BODY_FAT",
            "android.permission.health.WRITE_BODY_FAT",
            "android.permission.health.READ_SLEEP",
            "android.permission.health.READ_STEPS",
            "android.permission.health.READ_HYDRATION",
            "android.permission.health.WRITE_HYDRATION"
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HEALTH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isHealthConnectAvailable" -> {
                        result.success(isHealthConnectSupported())
                    }
                    "hasHealthPermissions" -> {
                        val allGranted = isHealthConnectSupported() && HEALTH_PERMISSIONS.all { perm ->
                            ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
                        }
                        result.success(allGranted)
                    }
                    "requestHealthPermissions" -> {
                        val opened = openHealthConnectPermissionsSettings()
                        result.success(opened)
                    }
                    "writeWeightAndBodyFat", "writeHydration" -> {
                        // La persistencia primaria ocurre en SQLite local (100% offline-first).
                        // Retornamos estado según permisos concedidos del sistema.
                        val hasPerms = isHealthConnectSupported() && HEALTH_PERMISSIONS.any { perm ->
                            ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
                        }
                        result.success(hasPerms)
                    }
                    "readSleepForDate" -> {
                        result.success(null)
                    }
                    "readStepsForDate" -> {
                        result.success(null)
                    }
                    "checkAppPermission" -> {
                        val perm = call.argument<String>("permission") ?: ""
                        if (perm == "android.permission.SCHEDULE_EXACT_ALARM") {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                val alarmManager = getSystemService(android.app.AlarmManager::class.java)
                                result.success(alarmManager?.canScheduleExactAlarms() == true)
                            } else {
                                result.success(true)
                            }
                        } else {
                            val granted = ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
                            result.success(granted)
                        }
                    }
                    "requestAppPermission" -> {
                        val perm = call.argument<String>("permission") ?: ""
                        if (perm == "android.permission.SCHEDULE_EXACT_ALARM") {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                try {
                                    val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                        data = Uri.fromParts("package", packageName, null)
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                } catch (_: Exception) {
                                    result.success(false)
                                }
                            } else {
                                result.success(true)
                            }
                        } else {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                requestPermissions(arrayOf(perm), 2001)
                            }
                            result.success(true)
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isHealthConnectSupported(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return getSystemService("healthconnect") != null
        }
        return try {
            packageManager.getPackageInfo(HC_PACKAGE, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openHealthConnectPermissionsSettings(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                    putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                }
            } else {
                Intent("androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS").apply {
                    putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                }
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val fallback = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                }
                startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}
