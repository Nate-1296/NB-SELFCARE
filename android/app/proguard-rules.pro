# NB Selfcare — reglas R8 propias.
# Los plugins de Flutter publican sus reglas de consumo en sus AAR; aquí solo va
# lo que la app necesita y no cubren ellos.

# Canales nativos propios (MainActivity y servicios de plataforma).
-keep class com.nb.selfcare.** { *; }

# Google Play Core es referenciado por el embedding de Flutter (deferred components)
# pero la app no lo usa.
-dontwarn com.google.android.play.core.**

# google_mlkit_text_recognition referencia los reconocedores de escrituras no latinas,
# que la app no incluye (solo se usa el modelo latino para tablas nutricionales).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
