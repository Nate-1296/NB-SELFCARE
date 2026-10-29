# Instrucciones para Agentes de IA en NB Selfcare (`AGENTS.md`)

> **Para cualquier modelo o agente de IA trabajando en este repositorio:**
> Este archivo define las reglas de conducta, restricciones arquitectónicas innegociables y estándares de calidad para el código generado en **NB Selfcare** (`com.nb.selfcare`).

---

## 1. Principios Inquebrantables de Ingeniería (Guardrails)

1. **100% Offline-First & Cero Telemetría:**
   * **PROHIBIDO:** Añadir dependencias de Firebase, Supabase, Google Analytics, Sentry remoto, Crashlytics o cualquier backend en la nube.
   * Única excepción documentada: ML Kit on-device para escáner y OCR (ADR-13). No ampara ningún otro SDK.
   * Lo que depende de un aparato (pantalla de papel, báscula, signos vitales) solo aparece si la persona lo declara en "Tus equipos" (ADR-14).
   * La única llamada HTTP permitida es a la API pública de **Open Food Facts** para resolver códigos de barras no cacheados. Todo resultado debe guardarse inmediatamente en SQLite local.
   * `android:allowBackup="false"` debe permanecer siempre en `AndroidManifest.xml`.
2. **Cero Placeholders y Código Completo:**
   * **PROHIBIDO:** Escribir comentarios como `// TODO: implement later`, `// Add remaining logic here` o truncar clases. Todo archivo creado o modificado debe ser funcional y compilar limpiamente.
3. **Tipado Estricto en Dart 3.x:**
   * No usar `dynamic` salvo cuando sea estrictamente indispensable en decodificación de JSON crudo antes de validación.
   * Respetar las reglas de `analysis_options.yaml` (`strict-casts`, `strict-inference`, `strict-raw-types`).
4. **Persistencia Reactiva en Drift:**
   * Las fechas se almacenan como texto ISO-8601 (`store_date_time_values_as_text: true`).
   * La edad nunca se almacena; se calcula al vuelo desde `birthDate` con la fecha del `Clock`.
   * La hora actual sale siempre de `Clock` (`clockProvider`); nunca `DateTime.now()` fuera de `core/clock`.
   * La presentación lee y escribe a través de `features/*/application/`, nunca con DAOs.
   * Los respaldos se realizan mediante `VACUUM INTO` sobre un archivo temporal seguro.
5. **Hardware Específico y Modo Dual:**
   * Toda vista debe verse y funcionar impecablemente en los temas de color y en **Modo Papel NXTPAPER E-Ink** (elevación 0, bordes sólidos de 1.5px, sin sombras difusas, sin animaciones ni estelas). Usa los tokens de `context.sc`, `context.type`, `ScRadius` y `ScMotion`.
   * Todo texto visible va en `lib/core/l10n/arb/app_es.arb`; las cifras con `NumberFormats` ("82,5", "2.500").
6. **Positividad Radical:**
   * La mascota virtual `Nibi` nunca muere, no enferma ni muestra mensajes de culpa o reproche.
7. **Registro de cambios:**
   * Todo cambio visible para el usuario se anota en `CHANGELOG.md`; las decisiones técnicas nuevas, como ADR en `docs/11_DECISIONS.md`.

---

## 2. Mapa de la documentación (`docs/`)

Antes de tocar una funcionalidad, lee su documento:

* [`docs/01_PRODUCT.md`](docs/01_PRODUCT.md): pantallas, principios, presupuesto de fricción (< 15 s) y alcance.
* [`docs/02_ARCHITECTURE.md`](docs/02_ARCHITECTURE.md): capas, estructura, flujo de datos, canales nativos y guardrails.
* [`docs/03_DATABASE.md`](docs/03_DATABASE.md): las 35 tablas (esquema v7), FTS5, migraciones y copias de seguridad.
* [`docs/04_BIOMETRICS_AND_SCALE.md`](docs/04_BIOMETRICS_AND_SCALE.md): trama BLE de la Mi Scale 2, 13 métricas, EMA, falsa subida y TDEE adaptativo.
* [`docs/05_NUTRITION.md`](docs/05_NUTRITION.md): Open Food Facts, semilla USDA, combos, texto y dictado, electrolitos, agua.
* [`docs/06_WORKOUT_AND_NEAT.md`](docs/06_WORKOUT_AND_NEAT.md): entrenamientos en 5 s y gasto neto por METs.
* [`docs/07_ANDROID_AND_DESIGN.md`](docs/07_ANDROID_AND_DESIGN.md): permisos, código Kotlin, modos color y papel, sistema de diseño.
* [`docs/08_NIBI_AND_REWARDS.md`](docs/08_NIBI_AND_REWARDS.md): Nibi (ánimo, animación, respiración, cosméticos) y monedas.
* [`docs/09_FASTING_JOURNAL_ANALYTICS.md`](docs/09_FASTING_JOURNAL_ANALYTICS.md): ayuno y sus fases, diario, cafeína y correlaciones.
* [`docs/10_PRIVACY_AND_TESTING.md`](docs/10_PRIVACY_AND_TESTING.md): privacidad y estrategia de pruebas.
* [`docs/11_DECISIONS.md`](docs/11_DECISIONS.md): decisiones de arquitectura (ADR-01 a ADR-17).
* [`docs/12_CARE.md`](docs/12_CARE.md): pestaña Cuidado (tratamientos, hábitos, suelo pélvico, pausas, signos vitales, síntomas, chequeos, alcohol y tabaco) y equipos declarados.

El historial de versiones está en [`CHANGELOG.md`](CHANGELOG.md).

---

## 3. Comandos de Verificación Frecuentes

```bash
# Análisis estático (objetivo: 0 errores, 0 warnings)
flutter analyze

# Generación de código de Drift y de los textos (ARB)
dart run build_runner build -d
flutter gen-l10n

# Pruebas (unitarias, widgets, migraciones, casos límite)
flutter test

# Capturas de todas las pantallas para revisión visual
flutter test tool/screenshots --update-goldens
```

