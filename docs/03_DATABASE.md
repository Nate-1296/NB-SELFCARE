# 03 · Base de datos

Un único archivo SQLite (`nb_selfcare.sqlite`) gestionado con Drift. Es la fuente de verdad de la app y, a la vez, la copia de seguridad del usuario.

## 1. Convenciones

- **Fechas como texto ISO-8601** (`store_date_time_values_as_text: true` en `build.yaml`): el archivo se lee con cualquier herramienta (DB Browser, Datasette, pandas).
- **`date_key` (`YYYY-MM-DD`)** en todo registro diario: agrupa por día de calendario local sin depender de zonas horarias.
- **Enums con `TypeConverter`** (`core/database/converters.dart`): se guarda el valor estable (`mi_scale_2_ble`, `breakfast`…), nunca el índice.
- **La edad no se guarda**: se calcula desde `birth_date`.
- **"Sin dato" ≠ 0**: los micronutrientes desconocidos son `NULL` y la UI muestra la cobertura (ADR-02).
- Snake case en SQL (`case_from_dart_to_sql: snake_case`). Claves foráneas activas (`PRAGMA foreign_keys = ON`) y WAL.

## 2. Tablas (esquema v7)

| Área | Tabla | Contenido |
| :-- | :-- | :-- |
| Perfil | `user_profiles` | Datos personales, metas, tema, fase de dieta, macros manuales, ciclado de calorías, banderas de seguridad. |
| | `ui_preferences` | Preferencias clave–valor (disposición de Inicio, pausas activas…). |
| | `reminders` | Recordatorios con hora, días y estado. |
| Cuerpo | `body_measurements` | Pesajes (báscula, manual, Health Connect) con tendencia EMA, métricas BIA, cinta métrica y fusión de grasa. |
| | `tdee_calibrations` | Historial del gasto adaptativo cada 14 días. |
| | `milestone_goals` | Metas intermedias de peso. |
| | `workout_blocks` | Entrenamientos (tipo, minutos, RPE, MET, kcal netas). |
| | `female_cycle_logs` | Ciclo menstrual. |
| Actividad | `daily_summaries` | Pasos, sueño (con fases) y FC en reposo por día. |
| | `health_sync_checkpoints` | Último punto sincronizado con Health Connect por tipo de dato. |
| Comida | `food_items` (+ índice FTS5) | Catálogo: semilla USDA en español, Open Food Facts, creados por el usuario. |
| | `food_logs` | Lo comido, con totales de macros y micronutrientes ya calculados. |
| | `meal_combos`, `meal_combo_items` | Combos habituales. |
| | `recipes`, `recipe_ingredients` | Recetas por lotes. |
| | `hydration_logs` | Cada vaso de agua. |
| | `caffeine_logs` | Tomas de cafeína. |
| | `supplements_tracker`, `supplement_logs` | Suplementos y su registro diario. |
| Ayuno | `fasting_sessions` | Ayunos (protocolo, inicio, fin, meta). |
| Diario | `journal_entries` | Texto, ánimo, energía, estrés, etiquetas y foto de progreso (JPEG reducido, dentro de la base de datos para que viaje en la copia). |
| | `digestive_logs` | Registro digestivo (escala de Bristol, molestias). |
| Nibi | `pet_status` | Nombre, monedas, racha, escudos, objetos desbloqueados y lo que lleva puesto (sombrero, accesorio, color, escenario). |
| | `coin_ledger` | Libro mayor de monedas; índice único `(date_key, action_type)` salvo compras → cada recompensa, una vez al día. |
| Plan | `protocol_plans` | Protocolo semanal (días de ayuno y entreno, estilo de comida). |
| Cuidado | `care_sessions` | Sesiones guiadas completas: suelo pélvico (con su nivel), pausas activas y descanso visual, respiración. |
| | `custom_habits`, `habit_logs` | Hábitos propios (nombre, icono, días) y su marca diaria (única por hábito y día). |
| | `checkups`, `checkup_logs` | Chequeos preventivos (catálogo o propios, intervalo en meses) y cuándo se hizo cada uno. |
| | `symptom_logs` | Síntomas con intensidad 1–5 y nota. |
| | `vital_readings` | Tensión, glucosa, oxígeno y temperatura, a mano o de Health Connect (`external_id` único: sin duplicados). |
| | `substance_logs` | Alcohol (bebidas estándar y kcal, enlazado a su registro en Comida) y tabaco. |
| | `wellbeing_checks` | Índice OMS-5 (respuestas y puntuación 0–100). |

El índice `food_items_fts` (FTS5, `unicode61 remove_diacritics 2`) se mantiene con tres *triggers* y permite buscar "platano" y encontrar "plátano".

## 3. Migraciones

`schemaVersion = 7`. Cada versión tiene su volcado en `drift_schemas/` y una migración paso a paso (`app_database.steps.dart`, generado con `dart run drift_dev make-migrations`):

| Versión | Cambio |
| :-: | :-- |
| 1 → 2 | Columnas de dieta, ciclo, cafeína y macros manuales en el perfil; tablas de recetas, suplementos, ciclo, digestión, cafeína, protocolo y metas. |
| 2 → 3 | `ui_preferences` pasa al esquema de Drift (se conservan las filas) e índices declarados. |
| 3 → 4 | Inicio de la fase de dieta y banderas de seguridad del perfil. |
| 4 → 5 | `equipped_accessory_id` y `equipped_color_id` en `pet_status`. |
| 5 → 6 | `progress_photo` (BLOB) en `journal_entries`: las fotos del diario entran en la copia de seguridad. |
| 6 → 7 | Equipos declarados (pantalla de papel, báscula, aparatos de signos vitales), módulos de Cuidado, avisos discretos y hora de dormir en el perfil; hora de despertar en `daily_summaries`; los suplementos pasan a tratamientos (tipo, varias horas, días, reserva, avisos, "baja la glucosa"); `slot_minutes` en las tomas; nueve tablas de Cuidado. Quien ya usaba la app conserva báscula y modos de papel. |

`test/drift/app_database/migration_test.dart` migra cada versión a todas las posteriores y comprueba que los datos sobreviven.

## 4. Copia de seguridad (`BackupService`)

- **Exportar**: `VACUUM INTO` a un archivo temporal privado y se comparte con el diálogo del sistema. La copia es consistente aunque la app esté escribiendo.
- **Restaurar**: se inspecciona el archivo (integridad, tablas mínimas, versión). Si es de una versión anterior, se migra una copia temporal con la misma estrategia de la app; luego se copian **todas** las tablas columna a columna en una transacción, se reconstruye el índice FTS5 y se notifica a la UI. El archivo original del usuario nunca se modifica.
- Un archivo que no es una copia de NB Selfcare (una foto, un ZIP, un `.sqlite` truncado o corrupto) se rechaza con un mensaje claro.
