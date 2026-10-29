# NB Selfcare

Autocuidado diario en un solo lugar: comida, agua, cuerpo, ayuno, descanso, medicamentos, suelo pélvico, pausas activas, signos vitales, chequeos, diario y **Nibi**, un dragón que te acompaña. Todo vive en tu teléfono: sin cuentas, sin nube y sin telemetría.

Probada en el **TCL 50 Pro NXTPAPER** (Android 16) con la báscula **Xiaomi Mi Body Composition Scale 2**, funciona en cualquier Android 8+: le dices qué equipos tienes y lo que no tienes no aparece.

---

## Qué hace

| Pestaña | Lo principal |
| :-- | :-- |
| **Inicio** | Disposición del día (sueño, pulso en reposo y esfuerzo), tarjetas que puedes ordenar y redimensionar (comida, agua, peso, pasos, sueño, entreno, ayuno, Nibi), diario rápido y revisión del domingo. |
| **Comida** | Buscador sin conexión, escáner de códigos con Open Food Facts, lectura de etiquetas nutricionales, dictado de comidas, combos con escalador, recetas por lotes, menú sugerido, balance energético, macros, electrolitos y agua. |
| **Cuerpo** | Pesaje en vivo con la Mi Scale 2 (13 métricas), peso tendencia, detector de "falsa subida", cinta métrica (US Navy), metas intermedias, evolución con gráfica y entrenamientos en 5 segundos. |
| **Cuidado** | Medicamentos y suplementos con avisos discretos y "Hecho" desde la notificación, hábitos propios, suelo pélvico guiado por vibración, pausas activas y descanso visual, signos vitales (si tienes el aparato), síntomas, chequeos preventivos y, si quieres, alcohol y tabaco. |
| **Nibi** | Su santuario: reacciona a tus hábitos reales, se deja acariciar, juega, respira contigo (respiración guiada 4-4-4-4, 4-7-8…), y se viste con lo que compras con tus monedas. |
| **Perfil** | Metas y gasto diario adaptativo (se recalibra cada 14 días), protocolo semanal, ciclo menstrual, informe PDF, ajustes, recordatorios, Health Connect y copias de seguridad. |

También: índice de bienestar OMS-5 con líneas de apoyo, regularidad del sueño, cronómetro de ayuno en la pantalla de bloqueo con fases metabólicas, recordatorios que sobreviven al reinicio, cafeína y sueño, registro digestivo y correlaciones entre tus hábitos.

## Principios

- **Sin conexión por diseño.** La única llamada de red es a Open Food Facts para un código de barras que no está en tu teléfono, y el resultado se guarda al instante.
- **Tus datos son tuyos.** Una copia de seguridad es un único archivo `.sqlite` legible con cualquier herramienta. `android:allowBackup="false"`.
- **Menos de 15 segundos** para cualquier registro, siempre con *Deshacer*.
- **Dos modos visuales**: color (24 temas, incluido Material You) y **Modo Papel** para pantallas NXTPAPER/E-Ink (si declaras una) (sin sombras ni animaciones, bordes de 1,5 px, sin estelas).
- **Positividad**: Nibi nunca enferma ni regaña; no hay castigos por olvidar un día.
- **No es un dispositivo médico.** La bioimpedancia y las fases del ayuno son estimaciones orientativas.

## Tecnología

Flutter 3.47 (Dart 3.13) · Riverpod 3 · Drift (SQLite con FTS5) · go_router · Kotlin para Health Connect, notificaciones y alarmas · ML Kit en el dispositivo para escáner y OCR (ADR-13).

```text
lib/
├── app/          # Armazón, rutas y barra inferior
├── core/         # Base de datos, plataforma (Android), servicios y dominio compartido
├── features/     # today · nutrition_hydration · body_metrics · fasting · journal ·
│                 # pet_gamification · profile_goals · protocol
└── shared/       # Sistema de diseño, utilidades y widgets comunes
```

Cada funcionalidad separa `domain/` (reglas puras), `application/` (casos de uso y consultas reactivas) y `presentation/` (widgets). Las pantallas nunca tocan la base de datos directamente; lo verifica un test de arquitectura.

## Desarrollo

```bash
flutter pub get
dart run build_runner build -d      # Drift
flutter gen-l10n                     # textos (lib/core/l10n/arb/app_es.arb)

flutter analyze                      # 0 avisos
flutter test                         # unitarios, widgets, migraciones, casos límite
flutter test tool/screenshots --update-goldens   # capturas de todas las pantallas

flutter build apk --release --split-per-abi --target-platform android-arm64
```

La firma de release usa `android/key.properties` si existe (no se versiona); si no, la de depuración.

## Documentación

Toda la documentación técnica está en [`docs/`](docs/README.md). Las reglas para colaborar (también para asistentes de IA) están en [`AGENTS.md`](AGENTS.md) y el historial de versiones en [`CHANGELOG.md`](CHANGELOG.md).
