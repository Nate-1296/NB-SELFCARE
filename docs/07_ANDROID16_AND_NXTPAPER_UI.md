# 07 · Especificación Android 16 (API 36) y Motor Visual NXTPAPER (`docs/07_ANDROID16_AND_NXTPAPER_UI.md`)

> **Contexto Técnico:** Configuración de permisos para **Android 16 (API 36)**, integración nativa de **Health Connect**, y diseño del motor visual dual optimizado para la pantalla antirreflejo y modo tinta del **TCL 50 Pro NXTPAPER**.

---

## 1. Manifiesto y Permisos de Android 16 (`AndroidManifest.xml`)

> **Actualizado (2026-10-26):** el manifiesto real añade `READ_RESTING_HEART_RATE`, `READ_HEALTH_DATA_IN_BACKGROUND`, `POST_PROMOTED_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `RECORD_AUDIO`, `<queries>` para Health Connect y el reconocedor de voz, el `activity-alias` de uso de permisos de Android 14+ y los receptores de recordatorios. La implementación nativa vive en `android/app/src/main/kotlin/com/nb/selfcare/` (ver `15_AUDITORIA_AAA.md` §9, Fase 3).

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.nb.selfcare">

    <!-- Bluetooth Low Energy en Android 12+ (API 31-36) sin rastreo de ubicación -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <!-- Health Connect Integrado en el Framework de Android 16 -->
    <uses-permission android:name="android.permission.health.READ_WEIGHT" />
    <uses-permission android:name="android.permission.health.WRITE_WEIGHT" />
    <uses-permission android:name="android.permission.health.READ_BODY_FAT" />
    <uses-permission android:name="android.permission.health.WRITE_BODY_FAT" />
    <uses-permission android:name="android.permission.health.READ_SLEEP" />
    <uses-permission android:name="android.permission.health.READ_STEPS" />
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED" />
    <uses-permission android:name="android.permission.health.READ_HEART_RATE" />
    <uses-permission android:name="android.permission.health.READ_HYDRATION" />
    <uses-permission android:name="android.permission.health.WRITE_HYDRATION" />

    <!-- Alarmas Exactas y Notificaciones de Ayuno -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

    <!-- Cámara para Escáner EAN-13 y Red exclusiva para Open Food Facts / Pesos IA -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:label="NB Selfcare"
        android:icon="@mipmap/ic_launcher"
        android:enableOnBackInvokedCallback="true"
        android:allowBackup="false"> <!-- Cero backups automáticos a la nube de Google -->

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <!-- Intent filters requeridos por las políticas de Health Connect -->
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

---

## 2. Motor Visual Dual: Material You vs. Modo Papel NXTPAPER

El **TCL 50 Pro NXTPAPER** incorpora una pantalla mate con acabado papel y un interruptor físico (*NXTPAPER Key*) para conmutar entre modo Normal, *Color Paper* e *Ink Paper* (estilo tinta electrónica monocromática).

La app implementa dos motores de diseño seleccionables en cualquier momento:

### Motor 1: Material You (`material_you`)
* Utiliza `dynamic_color` para extraer la paleta Monet del sistema operativo en Android 16.
* Elevaciones estándar Material 3, esquinas suaves y gradientes dinámicos en los anillos biométricos.

### Motor 2: Modo Papel E-Ink (`nxtpaper_eink`)
Diseñado para eliminar el efecto estela (*ghosting*), maximizar la legibilidad bajo la luz solar y emular un cuaderno impreso:

1. **Supresión Total de Sombras:**
   * `CardTheme(elevation: 0, shadowColor: Colors.transparent)`
   * `AppBarTheme(elevation: 0, scrolledUnderElevation: 0)`
   * `NavigationBarThemeData(elevation: 0)`
2. **Bordes Definidos de Tinta (1.5 px):**
   * Toda tarjeta, botón e input cuenta con un borde visible sólido de $1.5\text{ px}$ (`RoundedRectangleBorder(side: BorderSide(color: outline, width: 1.5))`).
3. **Paleta de Alto Contraste Monocromático / Mate:**
   * **Modo Claro Papel:** Fondo principal `#F7F5F0` (blanco hueso cálido mate), superficie de tarjetas `#FFFFFF`, texto y bordes en negro tinta `#121212`.
   * **Modo Oscuro Tinta:** Fondo principal `#101214`, superficie de tarjetas `#181A1D`, bordes y texto en marfil `#EAE6DF`.
4. **Cero Ghosting en Gráficas (Anti-Ghosting Animation):**
   * En modo `nxtpaper_eink`, la propiedad `swapAnimationDuration` de `fl_chart` se fuerza a `Duration.zero`. Esto evita que las transiciones fluidas dejen rastros grises difusos en la matriz de la pantalla.

