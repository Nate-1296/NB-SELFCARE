# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Universal BLE
-keep class com.navideck.universal_ble.** { *; }

# SQLite3 Native
-keep class org.sqlite.** { *; }

# Java / Kotlin attributes
-keepattributes *Annotation*,InnerClasses,Signature,EnclosingMethod

