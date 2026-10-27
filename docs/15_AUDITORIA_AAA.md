# 15 · Auditoría de Calidad AAA (`docs/15_AUDITORIA_AAA.md`)

> **Fecha:** 2026-10-26 · **Commit auditado:** `87f2f24` · **Alcance:** `lib/` (94 archivos, ~40.8k líneas sin generados), `test/` (18 archivos, 137 tests), `android/`, `assets/`, `docs/01–14`.
>
> **Objetivo:** contrastar lo que dicen los documentos con lo que hace el código y definir el camino para llevar NB Selfcare a calidad AAA (nivel Samsung Health / Apple Health / Google Fit).

---

## 1. Resumen ejecutivo

| Dimensión | Estado | Comentario |
| :-- | :-: | :-- |
| Análisis estático | ✅ | `flutter analyze`: 0 issues con reglas estrictas. |
| Tests | 🟡 | 137 tests en verde, pero **cobertura de líneas del 43.9%**; 8 pantallas/hojas con ~0%. |
| Matemática biométrica | ✅ | Parser BLE, EMA, US Navy, METs, TDEE y fórmulas Xiaomi bien aisladas y testeadas. |
| Arquitectura | 🔴 | Lógica de negocio dentro de widgets; sin capa de dominio/aplicación; pantallas de 1.4k–2.6k líneas. |
| Integraciones nativas | 🔴 | Health Connect, notificaciones, recordatorios e IA local son **simulados**. |
| Integridad de datos | 🔴 | La restauración de backup **pierde 9 de 25 tablas** y falla con backups v1. |
| Guardrail Zero‑Telemetry | 🔴 | `mobile_scanner` y `google_mlkit_text_recognition` usan ML Kit, que envía métricas de uso a Google. |
| Localización | 🔴 | ARB con 1 cadena; todo el texto está hardcodeado en español. |
| Release Android | 🔴 | Firma con clave debug, sin minify/shrink. |

**Diagnóstico:** el núcleo matemático y el modelo de datos son sólidos, pero la matriz de `docs/11` y `docs/14` marca como "✅ Completada" funcionalidades que hoy no existen o solo existen en la UI. Antes de pulir UI hay que (1) cerrar los bugs de pérdida de datos y de privacidad, (2) mover la lógica de negocio fuera de los widgets y (3) implementar de verdad las integraciones nativas.

---

## 2. Matriz de verdad: documentado vs. implementado

| Capacidad (doc) | Estado real | Evidencia |
| :-- | :-: | :-- |
| Lectura de sueño/pasos de Health Connect (`01` §4, `07`) | ❌ Simulado | `MainActivity.kt`: `readSleepForDate`/`readStepsForDate` devuelven `null`; no hay dependencia `androidx.health.connect`. |
| Escritura de peso/grasa/agua a Health Connect | ❌ Simulado | `MainActivity.kt`: `writeWeightAndBodyFat` solo comprueba permisos y devuelve `true` sin escribir nada. |
| `daily_summaries` (sueño, pasos, FC reposo) | ❌ Nunca se puebla | Solo la escribe `HealthSyncDao.upsertDailySummary`, alimentado por los métodos simulados. Por lo tanto **no funcionan**: multiplicador de sueño 1.5×, Readiness Score, correlaciones de sueño y NEAT. |
| Cronómetro de ayuno en pantalla de bloqueo (ADR‑06) | ❌ No existe | No hay `notification_service.dart` ni plugin de notificaciones. |
| Recordatorios exactos (`ReminderScheduler`) | ❌ Solo CRUD | `RemindersDao` guarda filas; nada las programa. |
| Pomodoro de sedentarismo (`14` Fase 5) | ❌ No existe | Cero referencias en `lib/`. |
| IA local (LiteRT / llama.cpp, TTL 120 s) | ❌ Simulado | `local_ai_service.dart`: `_touchOrLoad` cambia estados sin cargar nada; todo pasa por el fallback determinista. Además `isFromLlm: hasLocalModelFile` **marca como "IA" una respuesta determinista** si existe el archivo. |
| Dictado por voz on‑device (`05` §5) | ❌ No existe | Sin reconocimiento de voz en `lib/` ni en Android. |
| Preguntas de seguridad en onboarding (`01` §6: embarazo, marcapasos, TCA, diabetes) | ❌ No existe | Ninguna referencia en `lib/`. La impedancia nunca se desactiva por contraindicación. |
| Recalibración automática del TDEE al pesarse (`02` §3) | ❌ Solo manual | Únicamente `perfil_yo_screen.dart` (`_calibrateTdeeNow`). |
| Reverse dieting +50–100 kcal/sem (`14` Fase 4) | ❌ Incorrecto | `daily_targets_calculator.dart`: `reverse_diet` aplica un **−100 kcal fijo** (sigue siendo déficit). `diet_break` no caduca a los 7–14 días. |
| Fotos de progreso dentro del `.sqlite` (`01` §2) | ❌ | `JournalEntries.progressPhotoPath` guarda una ruta; el backup no incluye la foto. |
| Mascota procedural `CustomPainter` (ADR‑09) | ⚠️ Cambió | Ahora usa sprites PNG (decisión válida, pero el ADR no se actualizó). |
| Decodificador de barras zxing‑cpp sin Google Play Services (`01` §4) | ❌ | Se usa `mobile_scanner` (ML Kit). |
| UI localizable vía ARB | ❌ | `app_es.arb` tiene 8 líneas; nada en `features/` usa `AppLocalizations`. |

---

## 3. Hallazgos críticos (P0: corregir antes de cualquier otra cosa)

### P0‑1 · La restauración de backup pierde datos
`lib/core/services/backup_service.dart:21` — `_orderedTables` lista solo 16 tablas. Al restaurar se **omiten** `recipes`, `recipe_ingredients`, `supplements_tracker`, `supplement_logs`, `female_cycle_logs`, `digestive_logs`, `caffeine_logs`, `protocol_plans` y `milestone_goals`: quedan con los datos previos del dispositivo o vacías, y además referencian `food_items` con otros IDs.
Además, `INSERT INTO main.t SELECT * FROM ext_backup.t` falla en cuanto el backup tiene otro número de columnas (todo backup v1 en una app v2), y no se valida `PRAGMA user_version`.
**Arreglo:** derivar la lista de `_db.allTables`, copiar con columnas explícitas (intersección de esquemas), migrar backups antiguos abriendo una `AppDatabase` temporal sobre el archivo y añadir test de ida y vuelta con las 25 tablas.

### P0‑2 · Violación del guardrail Zero‑Telemetry (ML Kit)
`pubspec.yaml`: `mobile_scanner` (en Android usa ML Kit Barcode) y `google_mlkit_text_recognition`. Según su propia documentación, ML Kit envía a Google métricas de uso y rendimiento. Esto contradice `AGENTS.md` §1.1 y `01` §2.
**Opciones:** `flutter_zxing` (zxing‑cpp, el que pide `01` §4) para códigos de barras; para OCR, Tesseract on‑device (`flutter_tesseract_ocr`) o desactivar el OCR hasta tener una alternativa sin telemetría. *Requiere decisión del dueño del producto.*

### P0‑3 · Racha: un escudo cubre cualquier número de días perdidos
`lib/core/database/daos/pet_dao.dart:87-120` — solo mira si hubo actividad *ayer*. Si faltan 10 días seguidos, consume **1** escudo y la racha sigue. Debe consumir un escudo por día perdido y, si no alcanzan, reiniciar la racha (sin castigar a Nibi, que nunca muere ni regaña).

### P0‑4 · La cinta métrica contamina la EMA y regala monedas de pesaje
`body_measurements_dao.dart:151` — si no hay pesaje ese día, la medición Navy inserta `trendWeightKg = defaultWeightKg` (peso crudo, no EMA) y, al pasar por `insertMeasurement`, otorga `weigh_in` (+15). Esto rompe el cálculo del TDEE (`tdee_dao.dart` usa `measurements.first/last.trendWeightKg`).

### P0‑5 · Nibi "durmiendo" se muestra despierto
`animated_nibi_view.dart`: `NibiMood.sleeping` → `nibi_hero.png` (el dragón saludando). Faltan sprites 08 y 09.

### P0‑6 · Release Android inseguro
`android/app/build.gradle.kts`: `release` firma con `signingConfigs.debug`, `isMinifyEnabled = false`. Necesita un keystore propio (fuera del repo), R8 y reglas ProGuard.

---

## 4. Deuda arquitectónica (P1)

### 4.1 Lógica de negocio dentro de widgets
* **Cascada biométrica en la UI:** `cuerpo_screen.dart:216-361` calcula las 13 métricas, la EMA, el detector de retención (incluidos ciclo lúteo y creatina), construye el companion, persiste y exporta a Health Connect, todo dentro de un `State`. No se puede testear sin montar la pantalla, y la Health Connect "exportación" y el filtro de invitados quedan acoplados a `showDialog`.
* **Economía dispersa:** `grantDailyReward` se invoca desde **12 widgets distintos** con `actionType` como cadenas mágicas (`'meal_log_$_mealType'`, `'meal_log_repeat'`…). Cualquier cambio de reglas exige tocar la UI.
* **Acceso directo a DAOs:** 25 archivos de `features/` hacen `ref.read(xxxDaoProvider)`; `cuerpo_screen` solo, 12 veces.
* **Reloj no inyectable:** 61 llamadas a `DateTime.now()` (10 en `shop_modal.dart`, 8 en `perfil_yo_screen.dart`) aunque existe `current_date_provider.dart`. `DailyTargetsCalculator.compute` también lee el reloj por dentro (vía `calculateDynamicAge`). Resultado: tests no deterministas y bugs alrededor de medianoche.

### 4.2 Archivos monolíticos
| Archivo | Líneas |
| :-- | --: |
| `nutrition_hydration/presentation/nutricion_screen.dart` | 2 595 |
| `profile_goals/presentation/perfil_yo_screen.dart` | 2 430 |
| `today/presentation/widgets/hoy_bento_cards.dart` | 1 788 |
| `body_metrics/presentation/cuerpo_screen.dart` | 1 578 |
| `body_metrics/presentation/widgets/body_sheets.dart` | 1 498 |
| `pet_gamification/presentation/nibi_screen.dart` | 1 484 |
| `nutrition_hydration/presentation/widgets/nutrition_sheets.dart` | 1 407 |
| `today/presentation/hoy_screen.dart` | 1 399 |

Objetivo AAA: ningún archivo de presentación > 400 líneas; un widget público por archivo.

### 4.3 Capa de datos
* DAOs como clases planas en vez de `@DriftAccessor`; patrón "`getProfile()` + `update where id`" repetido 9 veces en `UserProfileDao`.
* Valores de dominio como `String` libres (`'male'`, `'deficit'`, `'weights'`, `'light'`, `'mi_scale_2_ble'`…). Deben ser `enum` con `TypeConverter` de Drift.
* `ui_preferences` se crea con SQL crudo en `beforeOpen`, fuera del esquema versionado.
* Sin tests de migración (`drift_dev schema dump` + `SchemaVerifier`).
* La interfaz `BodyScaleDriver` existe, pero la UI depende de `xiaomiMiScale2DriverProvider` (implementación concreta).

### 4.4 Desviaciones respecto a la spec
* Gasto neto por METs: el código usa `netMET × kg × h`; `06` §3 especifica `netMET × 3.5 × kg / 200 × min` (≈5% de diferencia). Hay que unificar.
* Multiplicador de sueño: `pet_dao.dart` usa 450 min fijos; `08` §4 dice `dailySleepGoalHours × 60`.
* `meal_log`: la spec limita a 3 comidas/30 monedas; el código también premia `snack` y `repeat`.
* `DailyTargetsCalculator.estimateBmr` usa `targetWeightKg` como peso de respaldo (debería ser el último peso real).

### 4.5 Localización y accesibilidad
* 0% de la UI pasa por ARB. Sin `Semantics` en anillos, gráficas ni Nibi. No se verificó escalado de texto al 200% ni contraste AA en Material You.

---

## 5. Calidad de tests

* **Cobertura 43.9%** (11 757 / 26 780 líneas, incluidos los generados). Áreas sin cobertura: `features/journal` 0%, `features/protocol` 0.5%, `recipe_builder_sheet` 0%, `barcode_scanner_sheet` 0.4%, `sunday_check_in_sheet` 0.5%, `supplement_tracker_sheet` 0%.
* No hay tests de: restauración de backup con todas las tablas, migración v1→v2, racha con varios días perdidos, el flujo completo de pesaje (que hoy no se puede testear porque vive en el `State`) ni golden tests en Modo Papel.
* `architecture_guardrails_test.dart` solo revisa imports de Dart; no detecta telemetría nativa transitiva (ML Kit). Debe ampliarse para revisar `pubspec.lock` y el grafo de dependencias de Gradle.

**Objetivo AAA:** ≥ 85% en `domain/` y `data/`, ≥ 60% en presentación, goldens en los dos temas × claro/oscuro, y tests de migración por cada `schemaVersion`.

---

## 6. Arquitectura objetivo

```text
lib/
├── app/                      # MaterialApp, router, shell, bootstrap (overrides de providers)
├── core/
│   ├── clock/                # Clock inyectable (reemplaza DateTime.now())
│   ├── database/             # AppDatabase, tablas, converters (enums), migraciones + schemas/
│   ├── platform/             # Puertos nativos: HealthConnectGateway, NotificationGateway, SpeechGateway
│   └── result/               # Result/Failure tipados
├── features/<feature>/
│   ├── domain/               # Entidades, enums, reglas puras (sin Flutter)
│   ├── data/                 # Repositorios sobre DAOs (@DriftAccessor) y gateways
│   ├── application/          # Casos de uso + Notifiers de Riverpod (orquestan la cascada)
│   └── presentation/         # Widgets < 400 líneas, sin acceso directo a DAOs
└── shared/                   # Design system (tokens, componentes), utilidades puras
```

Reglas:
1. `presentation` solo habla con `application` (Notifiers/casos de uso).
2. Un caso de uso por acción del usuario (`RecordWeighIn`, `LogMeal`, `LogWater`, `FinishFast`…), cada uno responsable de su cascada (EMA → retención → recompensa → Health Connect → TDEE).
3. Las recompensas se centralizan en `RewardPolicy` (dominio) + `CoinLedgerRepository`.
4. Todo lo nativo detrás de una interfaz con implementación *fake* para tests.
5. Un test de arquitectura que falle si `features/*/presentation` importa `core/database/daos`.

---

## 7. Plan de ejecución

| Fase | Contenido | Criterio de salida |
| :-- | :-- | :-- |
| **0 · Estabilización** | P0‑1 a P0‑6; actualizar `docs/11`, `docs/14` y ADR‑09 para que reflejen la realidad. | Backup con ida y vuelta de 25 tablas; racha correcta; sin ML Kit (o decisión registrada en un ADR). |
| **1 · Fundaciones** | `Clock` inyectable, enums con `TypeConverter`, `@DriftAccessor`, migración del esquema con `ui_preferences` versionada, tests de migración. | 0 `DateTime.now()` fuera de `core/clock`; schema v3 con tests. |
| **2 · Capa de aplicación** | Extraer casos de uso y `RewardPolicy`; cascada de pesaje y recalibración automática de TDEE; eliminar acceso a DAOs desde la UI. | Test de arquitectura en verde; cobertura de dominio ≥ 85%. |
| **3 · Integraciones reales** | Health Connect con el SDK oficial en Kotlin (Pigeon), notificación con cronómetro + Live Update, `AlarmManager` para recordatorios, voz on‑device, onboarding de seguridad. | Prueba manual en TCL 50 Pro + tests de contrato de los gateways. |
| **4 · Descomposición de UI + l10n** | Partir los 8 monolitos, design system en `shared/`, migrar textos a ARB, `Semantics`, goldens. | Ningún archivo de presentación > 400 líneas; goldens 4 variantes. |
| **5 · Pulido AAA** | Rediseño visual, microinteracciones, rendimiento (perfilado de frames). | Revisión de UX completa; 60 fps en Material You; 0 ghosting en Modo Papel. |
| **6 · Nibi 2.0** | Mascota animada (≥ 30 fps), set completo de estados y transiciones, reacción a datos reales, accesorios, P0-5. | Animación fluida en Material You y versión de bajo movimiento en Modo Papel. |

---

## 8. Decisiones del dueño del producto (2026-10-26)

1. **ML Kit:** solo se reemplaza si la alternativa es igual o mejor. Se mantiene (ADR-13). El escáner y la búsqueda en Open Food Facts no pueden degradarse.
2. **IA local:** se retira la promesa de "IA" de la UI; la app funciona con los motores deterministas hasta que exista un runtime real.
3. **Nibi:** se reemplazarán los sprites PNG por una mascota animada de verdad (≥ 30 fps). **Todo lo relacionado con la mascota va al final** del plan (incluido P0-5).
4. **Ejecución:** fases en orden, sin pausas salvo preguntas bloqueantes.

---

## 9. Bitácora de avance

### Fase 0 · Estabilización — completada
* **P0-1 Backup:** la restauración cubre todas las tablas del esquema (derivadas de `allTables`), copia por columnas compartidas, migra respaldos de versiones anteriores sobre una copia temporal y rechaza versiones futuras. `test/database/backup_restore_test.dart` cubre las 25 tablas, FTS5, `ui_preferences`, claves foráneas y la reversión ante un fallo.
* **P0-2 ML Kit:** ADR-13 (se mantiene por calidad).
* **P0-3 Racha:** `StreakPolicy` (dominio puro) consume un escudo por día perdido; si no alcanzan, la racha reinicia y los escudos se conservan. `test/features/streak_policy_test.dart`.
* **P0-4 Cinta métrica:** ya no sobrescribe pesajes de otros días ni inventa un peso; la fila de cinta arrastra peso y EMA sin modificarlos, no da monedas y se excluye del TDEE. La fusión 60/40 usa la grasa BIA del último pesaje real. `test/biometrics/navy_tape_persistence_test.dart`.
* **P0-5 Nibi dormido:** diferido a la fase de la mascota.
* **P0-6 Release:** firma con `android/key.properties` (fuera del repo), R8 + shrink de recursos, `proguard-rules.pro`.
* **IA:** textos de la UI sin promesas de IA; `isFromLlm` ya no se marca cuando solo existe el archivo del modelo.
* **APK:** el release universal pesa ~128 MB por incluir 3 ABIs; para el TCL 50 Pro usar `flutter build apk --release --split-per-abi` (arm64 ≈ 40 MB).

### Fase 1 · Fundaciones — completada
* **Reloj inyectable:** `lib/core/clock/clock.dart` (`Clock`, `Clock.fixed`, `clockProvider`). DAOs, servicios, driver BLE y backup lo reciben por constructor; las funciones puras (`calculateDynamicAge`, `DailyTargetsCalculator`, `FastingDosageAdvisor`, cafeína) exigen la fecha como parámetro. Guardrail 7 impide nuevos `DateTime.now()` (excepción temporal: partículas de Nibi).
* **Enums de dominio:** `lib/core/domain/enums.dart` (`BiologicalSex`, `DietPhase`, `DietArchetype`, `MealType`, `WorkoutCategory`, `RpeIntensity`, `MeasurementSource`, `FoodSource`, `ReminderType`) con `DbEnumConverter`: el texto guardado en SQLite no cambia y los valores desconocidos se leen con un valor por defecto en vez de romper. Se eliminaron los enums duplicados de `met_constants.dart` y se unificaron dos reglas distintas de "comida sugerida según la hora" en `MealType.forHour`.
* **Esquema v3:** índices declarados en Drift (incluidos 3 nuevos: `food_logs.food_item_id`, `fasting_sessions.started_at`, `journal_entries.date_key`), `ui_preferences` pasa a ser tabla del esquema conservando los datos, migraciones `stepByStep` y snapshots `drift_schemas/` v1–v3.
* **Tests de migración:** `test/drift/app_database/migration_test.dart` valida v1→v2→v3 y la integridad de datos (perfil, pesajes, comidas, `ui_preferences`, enums desconocidos).
* **Hallazgos nuevos (pendientes de fases siguientes):** `dynamic_color` declarado pero sin usar (Material You dinámico no existe); el onboarding calcula el TDEE inicial con el peso *meta* en vez del actual; Hoy, Nutrición y Perfil calculan las metas diarias con entradas distintas (peso tendencia, peso crudo o ninguno).

### Fase 2 · Capa de aplicación — completada
* **Casos de uso** (`features/*/application/`): `WeighInService` (cascada completa: 13 métricas → EMA → falsa subida → monedas → Health Connect → recalibración de TDEE si toca → mini-hitos), `TapeMeasurementService`, `WorkoutService`, `MilestoneService`, `TdeeCalibrationService`, `FoodLoggingService` (porción, combo, receta, texto libre, "repetir ayer" con Deshacer), `HydrationService`, `FastingService`, `JournalService`, `DailyActivityService`, `ProfileService`, `RewardService` y `dailyTargetsProvider`.
* **Dominio puro**: `RewardPolicy`, `StreakPolicy`, `WeighInAnalyzer`, `DietPhasePolicy`, `CyclePhaseCalculator`. Los DAOs ya no otorgan monedas: solo persisten.
* **Esquema v4**: `active_diet_phase_started_at` y las banderas de seguridad del onboarding (impedancia contraindicada, historial de TCA, medicación hipoglucemiante).
* **Bugs corregidos durante la extracción**:
  * Reverse diet real (+75 kcal/semana hasta mantenimiento) y diet break con vencimiento a los 14 días; techo de déficit de ~1 kg/semana (0,25 kg/semana con historial de TCA).
  * El arquetipo de dieta (keto, mediterránea…) ahora sí cambia el reparto de macros.
  * La compensación lútea (+150 kcal) nunca se aplicaba; ahora entra en las metas del día. La fase lútea se calcula como los últimos 14 días del ciclo en vez de "desde el día 17".
  * Hoy, Nutrición y Perfil comparten exactamente las mismas metas diarias.
  * La fase lútea y la creatina también explican una falsa subida (docs/14 Fase 6); el salto de agua por bioimpedancia exige impedancia real en ambos pesajes.
  * Los mini-hitos se marcaban durante el `build` del widget; ahora se evalúan con el Peso Tendencia dentro de la cascada del pesaje.
  * Dos fórmulas distintas de calorías netas de ejercicio → una sola, la ACSM de docs/06.
  * El registro manual de sueño inventaba minutos de REM/profundo; ya no. El multiplicador 1.5× usa la meta de sueño del perfil.
  * Guardar sueño/pasos en un día nuevo lanzaba excepción (`daily_summaries` exige metas NOT NULL).
  * "3 tomas de creatina en 7 días" no filtraba por fecha.
  * Los snacks y "repetir ayer" daban monedas fuera de la regla de docs/08 (3 comidas, 30 monedas/día).
  * Las hojas de arquetipos registraban comida sin pasar por las reglas (sin monedas).
  * Los valores de respaldo del extractor de texto se documentan por 100 g (el extractor ya los producía así).
* **IA**: `LocalAiService` (simulaba una GPU con TTL) se reemplaza por `TextAssistant`, honesto y determinista, con API asíncrona lista para un runtime real.
* **Guardrail 8**: la capa de presentación no puede invocar escrituras con reglas de negocio sin pasar por `application/`.
* **Pendiente para la Fase 4**: las *lecturas* (streams) de la UI aún usan proveedores definidos en los DAOs; se moverán a `application/` al descomponer las pantallas, y entonces se prohibirá importar `core/database/daos` desde `presentation/`.

### Fase 3 · Integraciones reales — completada (pendiente de validar en el TCL 50 Pro)
* **Health Connect real** (`android/.../health/HealthConnectBridge.kt`, SDK oficial `connect-client:1.1.0`): disponibilidad, permisos con el contrato oficial, lectura diaria de pasos, sueño con fases (profundo/REM) y FC en reposo, escritura de peso, grasa (solo si hubo bioimpedancia real) e hidratación. En Dart: `core/platform/health_connect_gateway.dart` + `HealthSyncService`, que sincroniza hoy y ayer al abrir/reanudar la app. Los datos sin permiso llegan como `null` y no pisan lo registrado a mano.
* **Cronómetro de ayuno en la pantalla de bloqueo** (`FastingNotifier.kt`): `setUsesChronometer`, solicitud de promoción a Live Update en Android 16 (`POST_PROMOTED_NOTIFICATIONS`) y actualización del texto en cada transición de fase metabólica con alarmas puntuales. `FastingService` lo muestra, retira y reconcilia.
* **Recordatorios reales** (`ReminderScheduler.kt`): `AlarmManager` exacto si hay permiso e inexacto si no; repetición por días y por intervalo (hidratación); se reprograman tras reinicio, cambio de hora o actualización de la app. `ReminderService` mantiene la tabla `reminders` como fuente de verdad y omite los avisos de ventana si el ayuno está desactivado. Tests JVM: `android/app/src/test/.../ReminderSpecTest.kt`.
* **Pausas activas** (`MovementNudgeWorker.kt`, WorkManager cada 15 min): con lectura en segundo plano de Health Connect, si hay < 120 pasos en la última hora entre 09:00 y 21:00 invita a moverse (máx. una vez cada 90 min). Interruptor en Ajustes.
* **Dictado on-device**: `speech_to_text` solo se activa si Android ofrece reconocimiento sin conexión (`SpeechRecognizer.isOnDeviceRecognitionAvailable`); nunca envía audio a la nube.
* **Onboarding seguro** (`OnboardingService`): peso actual (primer pesaje y base del TDEE inicial), descargo médico y preguntas de docs/01 §6. Marcapasos/implantes/embarazo → solo peso (también en el flujo BLE); antecedentes de TCA → déficit acotado y ayunos > 16 h desaconsejados; medicación hipoglucemiante → aviso antes de cada ayuno.
* **Privacidad**: pantalla `/privacidad`, abierta también cuando Health Connect lanza el intent de *rationale*.
* **Permisos**: `SystemPermissions` usa el contrato de resultado de Android (antes el resultado se ignoraba). Se eliminó el servicio simulado `HealthConnectService`.
* **Tests**: fakes de los puertos nativos (`test/support/fake_platform.dart`) y *mocks* globales de los canales en `test/flutter_test_config.dart` (resuelven los cuelgues intermitentes de los widget tests).
* **Validación pendiente en dispositivo**: todo compila (debug y release con R8), pero Health Connect, las notificaciones, Live Update, WorkManager y el dictado solo pueden verificarse en el teléfono. Lista de comprobación en §10.

### Fase 4 · UI y experiencia — completada (salvo Nibi, que va en la Fase 6)
Se trabaja por pantallas verticales (presentación + datos + textos + capturas).

**Base común:** tokens `ScSpace`/`ScRadius` (`shared/theme/sc_tokens.dart`), widgets `TonalBadge`, `CardHeader`, `MetricValue`, `ActionTile`, `UndoSnackbar`; textos en `lib/core/l10n/arb/app_es.arb` (`context.l10n`); fechas legibles con `DateFormats`. Los widget tests montan la app con los *delegates* de localización. El arnés acepta `--dart-define=FULL_PAGE=true` para capturar la página completa.

**Hoy — completada.**
* `hoy_screen.dart` pasa de un monolito a ~250 líneas: una tarjeta por archivo en `today/presentation/widgets/cards/`, edición del tablero en `layout_editing/`, acciones en `today_actions.dart`; `HoyLayoutController` vive en `application/` y los títulos de las tarjetas se traducen en presentación.
* **Disposición del día con datos reales.** Antes la tarjeta usaba la meta de sueño como sueño dormido, FC fija de 60 bpm y 1,5 h de entreno inventadas (y el PDF clínico, 7,5 h de sueño fijas). Ahora `readinessProvider` combina el sueño de esa noche, la FC en reposo frente a su media de 14 días (mín. 3 lecturas) y la carga real de 3 días (duración × RPE). Sin sueño registrado no hay puntuación: la tarjeta invita a registrarlo. El motor (`ReadinessEngine`) solo calcula; etiquetas y consejos están en el ARB.
* **Fases del ayuno unificadas** en `core/domain/metabolic_phase.dart` (0 · 4 · 12 · 18 · 24 h, docs/09). La tarjeta de Hoy anunciaba "autofagia" a las 16 h y Nibi "cetosis y autofagia profunda" desde las 14 h; ahora Hoy, la barra persistente, la pantalla de Ayuno, la etiqueta de Nibi y su saludo usan la misma fuente.
* **Cafeína:** la hora límite respeta `caffeineBedtimeCutoffHours` del perfil (8 h antes de dormir → 15:00) en lugar de 12:00 fijas; lectura y escritura pasan por `journal/application/caffeine_queries.dart`.
* **Check-in dominical:** el cambio de peso semanal tenía el signo invertido (una semana bajando mostraba "+"); ahora `WeeklyReview` usa los pesajes de los últimos 7 días naturales y se calcula una sola vez, no en cada toque.
* Textos sin jerga ("Peso", "Tendencia", "Grasa corporal", "Pasos", "Agua"); fecha del diario legible; la cabecera de Agua desbordaba 16 px en tarjetas 2×2.
* Tests nuevos en `test/application/readiness_and_caffeine_test.dart`. Suite: 205 tests en verde, `flutter analyze` sin avisos.
* Nota sobre las capturas: los emoji salen como "▤" porque el entorno de test no tiene fuente de emoji; en el teléfono se ven bien.

**Comida — completada.**
* `nutricion_screen.dart` pasa de 2.567 a ~330 líneas; las tarjetas viven en `nutrition_hydration/presentation/widgets/comer/` y leen de `nutritionDayProvider` (totales en `domain/nutrient_totals.dart`).
* **Balance semanal real.** La tarjeta pasaba un mapa vacío de consumos al servicio, así que siempre mostraba la meta completa como "ahorro". Ahora `weeklyCalorieBankProvider` suma lo comido en los días ya cerrados de la semana y solo cuenta la meta de los días con registros; sin días cerrados lo dice en lugar de inventar un saldo.
* **NOVA honesto.** Con alimentos sin grupo NOVA (todo el catálogo USDA) marcaba "100 % comida real"; ahora el porcentaje se calcula solo sobre lo clasificado y lo demás se indica aparte.
* Accesos de registro en cuadrícula de 2 columnas (adiós a "Escrib/ir", "Comb/os"); el tipo de dieta se cambia desde el balance semanal; fecha legible; ayuno con su fase real.
* Hojas (búsqueda, detalle, escáner, alimento propio, recetas, combos, menú sugerido, "qué comer ahora") sin DAOs: lecturas y ediciones por `FoodCatalogService` y `mealCombosProvider`; combos por `FoodLoggingService.saveCombo`. Los modelos de lectura (`FoodLogWithItem`, combos, recetas, calibración TDEE) pasan a `core/database/models/`.
* ~320 textos al ARB, sin jerga ("Batch cooking", "OCR", "EAN-13", "Arquetipos dietéticos", "Oráculo de nutrientes" → lenguaje llano). Las fichas de "Ciencia a demanda" quedan como contenido editorial en `comer/nutrient_science.dart`.
* Tests nuevos en `test/application/nutrition_day_test.dart`. Suite: 208 tests en verde.

**Cuerpo — completada.**
* `cuerpo_screen.dart` pasa de 1.441 a ~300 líneas: tarjetas en `body_metrics/presentation/widgets/cuerpo/` (peso, báscula, composición, movimiento) y catálogo de métricas en `cuerpo/body_metric_catalog.dart` (etiquetas en el ARB; las explicaciones largas quedan como contenido editorial).
* **Sesión de báscula testeable.** El flujo BLE (escaneo, espera de 10 s a la bioimpedancia, modo solo peso, descarte de tramas repetidas) sale del widget a `ScaleSession` (`application/scale_session.dart`) con 4 tests sobre una báscula simulada (`fake_async`).
* **Proteína corporal corregida.** La fórmula de docs/04 restaba `agua × 0,52`, así que casi cualquiera marcaba el tope del 26 % ("Óptimo"); ahora resta el agua completa como el algoritmo de openScale (≈ 20 % en el perfil de prueba). docs/04 actualizado y test de regresión.
* **Gráfica honesta.** El eje X era por índice (un hueco de dos semanas sin pesarse se veía igual que un día); ahora es por fecha. La tendencia es la línea principal y los pesajes diarios son puntos; fechas legibles en lugar de "10-26"; leyenda que no se solapa.
* **Kcal por pasos**: Hoy calculaba desde los pasos y Cuerpo leía la columna guardada (mostraba "0 kcal" con 9.700 pasos si no venían del servicio); ahora ambos usan `ActivityEnergy.kcalFromSteps`.
* Sin jerga: "BLE 0x181B / 0x181D", "Tendencia EMA", "US Navy", "Katch-McArdle", "Mini-hitos psicológicos", "RPE (5s)", "MET" en títulos → lenguaje llano. Fechas legibles en todo el flujo.
* Mini-metas por `milestonesProvider`; la pantalla ya no importa DAOs.
* Suite: 213 tests en verde.

**Ayuno — completada.**
* **Rendimiento:** la pantalla entera se reconstruía cada segundo y, al hacerlo, volvía a crear el `StreamBuilder` de la sesión activa (una consulta nueva a SQLite por segundo). Ahora solo `ActiveFastCard` se repinta (cada segundo; cada minuto en Modo Papel) y los datos llegan por `activeFastingSessionStreamProvider` / `recentFastsProvider`.
* `fasting_screen.dart` de 1.097 a ~230 líneas: `active_fast_card`, `fast_setup_card` (protocolos como enum), `phase_timeline` (generada desde `MetabolicPhase`, con descripciones prudentes: la autofagia ya no se promete) y `fast_history`.
* Las horas de inicio/fin dicen "ayer 23:10" cuando cruzan la medianoche; borrar un ayuno del historial se puede deshacer (`FastingService.restore`).
* Test nuevo: `test/application/fasting_history_test.dart`. Suite: 214 tests en verde.

**Perfil — completada.**
* Cabecera "Perfil" con acceso a Ajustes (por ruta `/ajustes`); `perfil_yo_screen.dart` de 2.442 a ~260 líneas, tarjetas en `profile_goals/presentation/widgets/perfil/`. Accesos (suplementos, digestión, protocolo, informe PDF) en cuadrícula.
* Lógica fuera de la UI: `ClinicalReportService` (datos del PDF), `ProfileService.saveAvatar` (copia la foto con nombre único para que no quede en caché y borra la anterior), `SupplementService` + `activeSupplementsProvider`, `CycleService`.
* **Descubrimientos**: el `FutureBuilder` recalculaba las correlaciones en cada reconstrucción de Perfil; ahora `crossInsightsProvider` las calcula una vez y el botón las invalida.
* **Ajustes**: al salir mientras se comprobaban permisos, la pantalla usaba `ref` ya desmontado (excepción); corregido.
* Sin jerga ("TDEE adaptativo", "Pearson r", "multivariables", "Calorie Cycling", "Refeed") y en minúsculas de frase. Helper de test `routedTestApp` para pantallas que navegan con go_router.

**Ajustes — completada.**
* Los 22 temas pasaban de una lista de 22 filas a una cuadrícula compacta separada en "Modo papel" y "Color"; los temas de papel se llaman "Papel claro / oscuro / en color".
* Nuevo orden: Apariencia → Recordatorios → Dispositivos → Secciones → Permisos → Tus datos (copia de seguridad y privacidad).
* Sin jerga: "VACUUM INTO", ".sqlite", "BLE Listo", "Santuario", "fases celulares", "SQLite puro", "Control quincenal US Navy".

**Mi protocolo — completada.**
* **El plan no se cargaba nunca**: la pantalla arrancaba siempre con L-X-V / 16:8 y pisaba lo guardado al pulsar Guardar; además no guardaba las horas de ayuno y escribía los días en un formato ("1,2,3") distinto del de la tabla (JSON día → horas). Ahora `WeeklyProtocol` (dominio) codifica y decodifica ambos formatos, `activeProtocolProvider` lo lee y la pantalla edita un borrador sobre lo guardado.
* **El plan sirve para algo**: la pantalla de Ayuno propone por defecto las horas planeadas para hoy.
* Desbordamiento de 138 px corregido (el selector de horario va en su propia fila); días con zonas táctiles de 44 dp; textos en el ARB.
* Tests: `test/domain/weekly_protocol_test.dart`. Suite: 217 tests en verde.

**Bienvenida (onboarding) — completada.**
* De un formulario larguísimo a 4 pasos cortos con barra de progreso: pantalla (color/papel) → sobre ti → metas → seguridad. "Siguiente" valida solo el paso actual.
* **Ritmo coherente con la meta:** antes se podía pedir "-0,5 kg/semana" con una meta por encima del peso actual. Ahora el sentido (perder/ganar/mantener) sale de la diferencia entre peso actual y meta, y el control solo fija el ritmo.
* Fecha legible, edad mínima de 14 años en el selector, sin jerga ("Santuario", "Motor visual", "fórmulas BIA", "SQLite").

**Diario: cafeína y digestión — completadas.**
* Los síntomas digestivos se guardan como códigos (`bloating`, `gas`…) con `jsonEncode` (antes se concatenaba un JSON a mano) y el historial mostraba el JSON crudo (`· ["Gases"]`); ahora muestra las etiquetas.
* Borrar una toma de cafeína o un registro digestivo se puede deshacer. Lecturas y escrituras por `caffeineDayProvider`/`CaffeineService` y `digestiveLogsProvider`/`DigestiveService`.

**Transversal.**
* **Guardrail 10** (`architecture_guardrails_test.dart`): ninguna pantalla importa DAOs; excepción temporal documentada para Nibi y su tienda (se reescriben en la Fase 6).
* **Modo Papel sin tintes:** el `ColorScheme` derivado del color semilla teñía de azul los controles seleccionados (segmentos, chips); en los temas de papel los contenedores pasan a tinta y papel.
* **Material You real:** nuevo tema "Colores de tu fondo" (`dynamic_color`, declarado pero sin usar hasta ahora): acento del fondo de pantalla y modo claro/oscuro del sistema.
* **Privacidad:** la pantalla explica ML Kit on-device y sus métricas técnicas (ADR-13) y el dictado sin conexión.
* Suite: 219 tests en verde, `flutter analyze` sin avisos.

**Accesibilidad y tamaño de archivos.**
* Nuevo `test/accessibility/guidelines_test.dart`: Hoy, Comida, Cuerpo, Perfil, Ayuno, Ajustes y Mi protocolo pasan `labeledTapTargetGuideline` y `androidTapTargetGuideline` (zonas táctiles de 48 dp con etiqueta). Corregido: barra inferior (46 → 52 dp), chips (`ChipPill` con 48 dp mínimos), flechas y días de la semana en Comida, días en Mi protocolo, "Editar perfil", botón atrás de Ajustes, avatar y "nuevo pensamiento" de Nibi en Hoy (sin etiqueta).
* Márgenes de tarjeta unificados a 16 dp (`HealthCard`), igual que `ScSpace.gutter`.
* Archivos partidos por responsabilidad: hojas de nutrición (dictado, combos, crear combo, vaso a medida, recetas guardadas, selector de ingredientes, menú sugerido, "qué comer ahora"), hojas de cuerpo (pesaje manual, cinta, ajustes de báscula, detalle de métrica), secciones de Ajustes, partes del buscador y del detalle de alimento, pintor de la gráfica, diario (ánimo, historial). Quedan entre 400 y 670 líneas algunos formularios con mucho estado compartido (alimento propio, detalle de alimento, constructor de recetas, gráfica, registro de entreno, escáner, bienvenida); y Nibi/tienda, que se rehacen en la Fase 6.
* Suite: 226 tests en verde.

**Pendiente de la Fase 4 (deuda conocida).**
* Textos generados en `core/` (saludos de Nibi, avisos de seguridad del ayuno, PDF clínico, motor de correlaciones, explicaciones de retención) siguen en español dentro del dominio; para otro idioma habría que devolver claves en lugar de frases.
* Nibi y la tienda: se rehacen en la Fase 6.

## 10. Comprobación manual en el TCL 50 Pro (Fase 3)
1. Instalar `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
2. Onboarding: completar con peso actual; verificar que Cuerpo muestra el primer pesaje.
3. Ajustes → Health Connect → conceder permisos → en Hoy, el resumen de sueño/pasos se rellena solo.
4. Pesarse con la Mi Scale 2 → el peso aparece en la app Health Connect.
5. Iniciar un ayuno → bloquear el teléfono → cronómetro visible (y chip de Live Update en la barra de estado).
6. Ajustes → Recordatorios: poner uno a 2 minutos vista → llega la notificación; reiniciar el teléfono y comprobar que sigue programado.
7. Comer → Escribir comida → micrófono: dictar "200 gramos de pollo y una manzana" en modo avión.
8. Ajustes → Pausas activas: activar y no caminar durante una hora (entre 09:00 y 21:00).

## 11. Revisión visual (arnés de capturas)
`flutter test tool/screenshots --update-goldens` siembra 30 días de datos realistas y genera PNG de cada pantalla (tema oscuro y Modo Papel) en `tool/screenshots/goldens/`. Hallazgos:
* **Corregido**: en Modo Papel, la puntuación de Readiness y los chips "ÓPTIMO"/"Activo" eran bloques negros (relleno `line2` + texto `accent`, ambos tinta). 15 rellenos pasan a `bg3`.
* ~~**Mi Protocolo** desborda 138 px~~ → corregido (Fase 4).
* ~~**Comida**: las tarjetas de acciones parten palabras~~ → corregido (Fase 4).
* Márgenes horizontales inconsistentes entre tarjetas (18 vs 36 px), Perfil sin cabecera. ~~Fecha ISO cruda en Cuerpo~~ → corregido.
* Jerga en la capa principal: "BLE 0x181B / 0x181D", "Tendencia EMA", "Batch cooking", "Escala 0.25x-3x", "RPE 8–9", "Sueño (40p)".
* ~~Límite de cafeína a las 12:00~~ → corregido en la vertical de Hoy (§9, Fase 4).
* Dos estilos de arte de Nibi conviven (avatar con gorra y gafas vs. sprite) → Fase 6.

