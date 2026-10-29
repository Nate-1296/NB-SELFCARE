# 12 · Cuidado

> La pestaña **Cuidado** (`/cuidado`) reúne lo que no es comida, cuerpo ni Nibi pero también es cuidarse. Código en `lib/features/care/`; las decisiones, en ADR-14 a ADR-17 de [`11_DECISIONS.md`](11_DECISIONS.md).

## 1. Principios

- **Cada apartado es opcional.** Ajustes → Módulos → "Apartados de Cuidado" (`user_profiles.care_modules_json`). Alcohol y tabaco empieza apagado.
- **Lo que no tienes no aparece.** Los signos vitales solo se ven si en Ajustes → Tus equipos marcas el aparato (tensiómetro, glucómetro, oxímetro, termómetro).
- **Discreción.** Los avisos de tomas no dicen el nombre del medicamento (Ajustes → Recordatorios → Avisos discretos, activado por defecto) y el de suelo pélvico siempre dice "Tu momento de 3 minutos". En la pantalla de bloqueo, todos los recordatorios son privados.
- **Explicaciones para quien las quiera.** Cada apartado tiene su "Saber más" (`CareScience`, textos en el ARB) con qué es, cómo funciona, qué hacer y fuentes.
- **Sin regaños.** Una toma se marca "tomada" u "omitida"; nunca "olvidada". Los medicamentos no dan monedas: un tratamiento no es un juego.

## 2. Apartados

| Apartado | Qué hace | Detalle |
| :-- | :-- | :-- |
| **Medicamentos y suplementos** | Tomas del día por hora; un toque = tomada, pulsación larga = omitida; ambas con Deshacer. | Varias horas por tratamiento, días de la semana, reserva con aviso a 7 días, aviso con botón "Hecho" que funciona con la app cerrada (`ReminderActionReceiver` guarda la acción y la app la aplica al abrirse). "Puede bajar el azúcar" activa el aviso antes de ayunar. "Retiene agua" (creatina) sigue alimentando la falsa subida del pesaje. |
| **Mis hábitos** | Hábitos propios (hilo dental, protector solar…) con icono y días; un toque los marca. | Completar todos los del día da monedas una vez. |
| **Suelo pélvico** | Programa en 5 niveles: lentas (3–10 s), rápidas y relajación final; "Solo relajar" para quien nota tensión. | Guiado por vibración (un pulso largo = aprieta; dos cortos = suelta) para hacerlo sin mirar. Propone subir de nivel tras 6 sesiones; nunca obliga. |
| **Pausas activas** | Cinco rutinas de 1 a 3 min: cuello y hombros, espalda, muñecas, caderas y piernas, descanso visual (20-20-20). | Figura de trazo dibujada en código (`StickFigurePainter`), sin imágenes. Aviso opcional de descanso visual cada hora hasta las 18:30. |
| **Signos vitales** | Última lectura y su lectura orientativa (AHA 2017, ADA, OMS); historial con borrado. | A mano o leídos de Health Connect (solo los tipos declarados; sin duplicados por `external_id`). Valores imposibles se rechazan (mmol/L, °F). |
| **Síntomas** | Catálogo de un toque + texto propio, intensidad 1–5. Con ciclo activo: cólicos, sensibilidad, hinchazón; desde los 40: sofocos, sudores, niebla mental, sequedad. | Entran en las correlaciones (sueño ↔ síntomas) y en el informe PDF. La digestión (Bristol) se abre desde aquí. |
| **Chequeos preventivos** | Lista según edad y sexo (Resolución 3280 de 2018 y OMS), intervalos editables y chequeos propios. | Estados: toca ya, en N días, sin registrar, próximo. "Ya lo hice" pide la fecha y da monedas. |
| **Alcohol y tabaco** | Un toque por bebida o cigarrillo; semana en bebidas estándar (10 g) y comparación positiva con la anterior. | Cada bebida suma sus kcal en Comida como tentempié (para el balance y el gasto adaptativo); deshacer las quita. Correlación alcohol → sueño de esa noche. |

## 3. Fuera de la pestaña

- **Tus equipos** (Ajustes y bienvenida): pantalla de papel, báscula Mi Scale 2 y aparatos de signos vitales. Sin pantalla de papel no se ofrecen los temas de papel; sin báscula, Cuerpo muestra "Tu peso" (registro a mano y cinta) y solo IMC, metabolismo basal y grasa por cinta. Quien ya usaba la app (v6) conserva báscula y papel.
- **Inicio**: tarjeta "Cuidado de hoy" (tomas pendientes con "Tomada" de un toque y progreso de hábitos).
- **Revisión del domingo**: índice de bienestar OMS-5 opcional. Por debajo de 29/100 se muestran las líneas de apoyo.
- **Sueño**: hora de despertar (manual o de Health Connect) y **regularidad del horario** (desviación circular del punto medio de la noche en 14 días). "Tu hora de dormir" mueve la hora límite de la cafeína y el aviso de desconectar.
- **Ciclo**: en fase lútea o menstrual, Cuerpo recuerda que es normal retener 0,5–2 kg de agua.
- **Respiración** (Nibi): se guarda como sesión y, si está conectado, como sesión de mindfulness en Health Connect.
- **Líneas de apoyo** (Cuidado y Ajustes): Línea 192 opción 4, Línea 106 y 123. Pulsar abre el marcador con el número escrito; nunca llama sola.
- **Informe PDF**: medicamentos y suplementos, media de signos vitales y síntomas más frecuentes de 30 días.

## 4. Capas

| Capa | Piezas |
| :-- | :-- |
| `domain/` | `GuidedSequence`, `PelvicFloorProgram`, `ActiveBreakRoutine` (+ `StickPose`), `CheckupCatalog`/`CheckupDue`, `TreatmentSchedule`, `VitalRanges`, `WellbeingIndex`, `SubstancePreset`, `SymptomCatalog`; `today/domain/SleepRegularity`. |
| `application/` | `TreatmentService`, `HabitService`, `CareSessionService`, `CheckupService`, `SymptomService`, `VitalService`, `SubstanceService`, `WellbeingService`, `CarePreferencesService` y `care_queries.dart`. |
| `core/` | `CareDao`, `SupplementDao` ampliado, `DeviceGateway` (modelo, marcador, vibración), Health Connect (signos vitales y mindfulness), acciones de notificación. |

Pruebas: `test/care/care_domain_test.dart` (reglas puras) y `test/care/care_services_test.dart` (casos de uso sobre SQLite en memoria).
