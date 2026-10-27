# Instrucciones para Agentes de IA en NB Selfcare (`AGENTS.md`)

> **Para cualquier modelo o agente de IA trabajando en este repositorio:**
> Este archivo define las reglas de conducta, restricciones arquitectónicas innegociables y estándares de calidad para el código generado en **NB Selfcare** (`com.nb.selfcare`).

---

## 1. Principios Inquebrantables de Ingeniería (Guardrails)

1. **100% Offline-First & Cero Telemetría:**
   * **PROHIBIDO:** Añadir dependencias de Firebase, Supabase, Google Analytics, Sentry remoto, Crashlytics o cualquier backend en la nube.
   * Única excepción documentada: ML Kit on-device para escáner y OCR (ADR-13). No ampara ningún otro SDK.
   * La única llamada HTTP permitida es a la API pública de **Open Food Facts** para resolver códigos de barras no cacheados. Todo resultado debe guardarse inmediatamente en SQLite local.
   * `android:allowBackup="false"` debe permanecer siempre en `AndroidManifest.xml`.
2. **Cero Placeholders y Código Completo:**
   * **PROHIBIDO:** Escribir comentarios como `// TODO: implement later`, `// Add remaining logic here` o truncar clases. Todo archivo creado o modificado debe ser funcional y compilar limpiamente.
3. **Tipado Estricto en Dart 3.x:**
   * No usar `dynamic` salvo cuando sea estrictamente indispensable en decodificación de JSON crudo antes de validación.
   * Respetar las reglas de `analysis_options.yaml` (`strict-casts`, `strict-inference`, `strict-raw-types`).
4. **Persistencia Reactiva en Drift:**
   * Las fechas se almacenan como texto ISO-8601 (`store_date_time_values_as_text: true`).
   * La edad nunca se almacena como un entero estático; se calcula dinámicamente con `DateTime.now().difference(birthDate).inDays / 365.25`.
   * Los respaldos se realizan mediante `VACUUM INTO` sobre un archivo temporal seguro.
5. **Hardware Específico y Modo Dual:**
   * Toda vista debe verse y funcionar impecablemente tanto en **Material You** como en **Modo Papel NXTPAPER E-Ink** (elevación 0, bordes sólidos de 1.5px, sin sombras difusas, sin estelas ni ghosting en gráficas).
6. **Positividad Radical:**
   * La mascota virtual `Nibi` nunca muere, no enferma ni muestra mensajes de culpa o reproche.

---

## 2. Mapa Rápido de Documentación (`docs/`)

Antes de implementar cualquier característica, consulta su especificación técnica:

* [`docs/01_PRODUCT_SPEC.md`](docs/01_PRODUCT_SPEC.md): Alcance funcional, páginas y reglas de interacción (< 15 segundos).
* [`docs/02_ARCHITECTURE.md`](docs/02_ARCHITECTURE.md): Capas del sistema, flujo reactivo y estructura de directorios.
* [`docs/03_DATABASE_SPEC.md`](docs/03_DATABASE_SPEC.md): Esquema de las 14 tablas en Drift, triggers FTS5 y backup SQLite.
* [`docs/04_BIOMETRICS_AND_SCALE.md`](docs/04_BIOMETRICS_AND_SCALE.md): Parser de 13 bytes BLE Mi Scale 2, las 13 métricas, EMA, detector de retención y TDEE adaptativo.
* [`docs/05_NUTRITION_ENGINE.md`](docs/05_NUTRITION_ENGINE.md): Open Food Facts, semilla USDA en español, combos caseros y triángulo de electrolitos.
* [`docs/06_WORKOUT_AND_NEAT.md`](docs/06_WORKOUT_AND_NEAT.md): Bloques rápidos RPE en 5 segundos y fórmulas de gasto calórico neto por METs.
* [`docs/07_ANDROID16_AND_NXTPAPER_UI.md`](docs/07_ANDROID16_AND_NXTPAPER_UI.md): Permisos Android 16 (API 36), Health Connect y tema de alto contraste NXTPAPER.
* [`docs/08_LOCAL_AI_AND_GAMIFICATION.md`](docs/08_LOCAL_AI_AND_GAMIFICATION.md): Ciclo de vida de memoria GPU (120s TTL), prompts deterministas, lienzo procedural de Nibi y CoinLedger.
* [`docs/09_FASTING_JOURNAL_ANALYTICS.md`](docs/09_FASTING_JOURNAL_ANALYTICS.md): Cronómetro de ayuno con fases metabólicas, diario privado y motor de correlaciones.
* [`docs/10_SECURITY_AND_TESTING.md`](docs/10_SECURITY_AND_TESTING.md): Suite de pruebas unitarias y verificación de fugas de red.
* [`docs/11_ROADMAP.md`](docs/11_ROADMAP.md): Plan de ejecución modular en 6 fases.
* [`docs/12_DECISIONS.md`](docs/12_DECISIONS.md): Registro de decisiones de arquitectura (ADR-01 a ADR-12).
* [`docs/13_COMPETITIVE_ANALYSIS_AND_VALUE_GAPS.md`](docs/13_COMPETITIVE_ANALYSIS_AND_VALUE_GAPS.md): Benchmark de mercado y brechas de valor.
* [`docs/14_MASTER_IMPLEMENTATION_PLAN.md`](docs/14_MASTER_IMPLEMENTATION_PLAN.md): Plan maestro de las 7 fases de expansión.
* [`docs/15_AUDITORIA_AAA.md`](docs/15_AUDITORIA_AAA.md): Auditoría de calidad (documentado vs. implementado), hallazgos P0/P1 y arquitectura objetivo. **Leer antes de tocar código.**

---

## 3. Comandos de Verificación Frecuentes

```bash
# Análisis estático (objetivo: 0 errores, 0 warnings)
flutter analyze

# Generación de código de Drift y Riverpod
dart run build_runner build -d

# Ejecución de pruebas unitarias
flutter test
```

