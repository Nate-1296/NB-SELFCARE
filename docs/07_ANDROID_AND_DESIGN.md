# 07 · Android y sistema visual

> Permisos y piezas nativas de Android, y el sistema visual con sus dos modos: color y papel (NXTPAPER/E-Ink).

---

## 1. Android

`minSdk 26` (Android 8), `targetSdk 36` (Android 16). Release con R8 (`isMinifyEnabled = true`) y firma propia si existe `android/key.properties`.

### 1.1 Permisos

| Permiso | Para qué | Cuándo se pide |
| :-- | :-- | :-- |
| `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT` | Leer la báscula. En Android ≤ 11 se declaran `BLUETOOTH`, `BLUETOOTH_ADMIN` y ubicación (solo hasta API 30). | Al pulsar "Pesarme". |
| `health.READ_*` (peso, grasa, sueño, pasos, FC en reposo, hidratación, lectura en segundo plano) y `health.WRITE_*` (peso, grasa, hidratación) | Health Connect. | Al conectar Health Connect en Ajustes. |
| `POST_NOTIFICATIONS` | Cronómetro del ayuno, recordatorios, pausas activas. | Al empezar un ayuno o activar un recordatorio. |
| `POST_PROMOTED_NOTIFICATIONS` | Live Update del ayuno en Android 16. | Con el anterior. |
| Health Connect: lectura de tensión, glucosa, oxígeno y temperatura | Signos vitales de los aparatos declarados (ADR-16). | Al marcar el aparato en Tus equipos, o al conectar Health Connect. |
| `health.WRITE_MINDFULNESS` | Guardar las sesiones de respiración. | Con el permiso base de Health Connect, si el proveedor lo soporta. |
| `VIBRATE` | Guiar el suelo pélvico sin mirar la pantalla. | Permiso normal (no se pregunta). |
| `SCHEDULE_EXACT_ALARM` | Recordatorios a la hora exacta (sin él, ventana de hasta una hora). | Desde Ajustes → Permisos. |
| `RECEIVE_BOOT_COMPLETED` | Reprogramar recordatorios y el ayuno tras reiniciar. | — |
| `CAMERA` | Escáner y lectura de etiquetas. | Al abrir el escáner. |
| `RECORD_AUDIO` | Dictado de comidas (reconocimiento en el dispositivo). | Al tocar el micrófono. |
| `INTERNET` | Solo Open Food Facts. | — |

`android:allowBackup="false"`. El manifiesto declara las acciones que exige Health Connect (`ACTION_SHOW_PERMISSIONS_RATIONALE` y `VIEW_PERMISSION_USAGE` con el `activity-alias` de Android 14+), que abren la política de privacidad (`/privacidad`).

### 1.2 Código nativo (`android/app/src/main/kotlin/com/nb/selfcare/`)

| Clase | Qué hace |
| :-- | :-- |
| `MainActivity` | Canales de Flutter, permisos en tiempo de ejecución, ajustes, disponibilidad del dictado sin conexión, modelo del teléfono, marcador (líneas de apoyo) y vibración. |
| `health/HealthConnectBridge` | SDK oficial de Health Connect: permisos, lecturas diarias (pasos, sueño con fases y hora de despertar, FC en reposo), signos vitales declarados y escrituras (peso, grasa, hidratación, sesiones de respiración). |
| `notifications/FastingNotifier` | Notificación del ayuno con `setUsesChronometer` (el sistema cuenta los segundos sin la app viva), promovida a Live Update en Android 16; cambia el texto en cada fase y a medianoche con alarmas inexactas. Sin servicio en primer plano (ADR-06). |
| `notifications/ReminderScheduler` + `ReminderReceiver` | Recordatorios con `AlarmManager` (exactos si hay permiso), privados en la pantalla de bloqueo. |
| `notifications/ReminderActionReceiver` | Botón "Hecho" de las tomas: guarda la acción (sin abrir la app) y Flutter la aplica al volver (`consumeReminderActions`). |
| `notifications/RescheduleReceiver` | Reprograma todo al reiniciar, al cambiar la hora o al conceder alarmas exactas. |
| `notifications/MovementNudgeWorker` | Pausas activas: si Health Connect no registra pasos en una hora (entre 09:00 y 21:00), una invitación amable a moverse. |

---

## 2. Dos modos visuales

El **TCL 50 Pro NXTPAPER** tiene una tecla física que cambia la pantalla a papel en color o a tinta. La app no depende de esa tecla: cada tema declara si es de papel (`ScColors.isFlat`) y toda la interfaz se adapta.

| | Color | Papel |
| :-- | :-- | :-- |
| Superficies | Tonos, sin sombras difusas (elevación 0). | Papel del tema con filetes de tinta de 1,5 px. |
| Esquinas | 24/18/14 dp. | 14/10/8 dp, aspecto de ficha impresa. |
| Movimiento | Microinteracciones (ver §3.3). | Ninguna: cada cambio es un solo refresco, sin estelas (*ghosting*). |
| Gráficas y anillos | Animados al cambiar. | Instantáneos; series distinguidas por grosor y trazo, no solo por color. |
| Nibi | Animado a la frecuencia de la pantalla. | Pose fija por actividad, con paleta de tinta. |

## 3. Sistema de diseño

Hay **un catálogo de temas** (`lib/shared/theme/sc_theme.dart`) y cada tema declara si es de papel (`isFlat`). Todo componente lee los tokens con `context.sc`, `context.type` y `ScRadius`/`ScMotion`.

### 3.1 Catálogo
* **Papel (NXTPAPER):** solo se ofrecen si en Tus equipos está marcada la pantalla de papel (ADR-14). Papel en color, Papel claro, Papel oscuro y **Papel sepia** (tinta marrón sobre crema, menos luz azul de noche).
* **Color:** 20 temas oscuros y claros, entre ellos **Salvia y Lino** (claro cálido con verde salvia) y "Colores de tu fondo" (Material You dinámico).
* Todos cumplen contraste AA: `test/design_system/theme_catalog_test.dart` falla si un tema nuevo no lo cumple (texto ≥ 7:1, secundario y terciario ≥ 4,5:1, texto de botón sobre acento ≥ 4,5:1, acento ≥ 3:1).
* En tinta, carbohidratos y grasas se distinguen por intensidad: se calculan como tinta diluida sobre el papel del propio tema (también en sepia).

### 3.2 Reglas visuales
* **Jerarquía por tipografía, no por cajas.** Las cifras usan SpaceGrotesk con dígitos tabulares (`context.type.metricXL…metricS`), la unidad va pequeña y en tono secundario (`MetricValue`). Los rótulos sobre cifras van en versalitas (`overline`).
* **Una acción principal por bloque.** `FilledButton` solo para la acción principal; las acciones de tarjeta usan `QuickActionButton` (tonal del color de la categoría) y las secundarias son botones de texto.
* **Sin cajas dentro de cajas.** En color, las superficies interiores se distinguen por tono (`bg3`), sin filete; el filete de 1,5 px en tinta solo existe en papel. Las métricas relacionadas van en una sola tarjeta con filetes entre celdas (composición corporal, metas).
* **El icono no lleva recuadro**: la categoría la da su color (`CardHeader`, `MetricLabel`).
* **Esquinas:** 24/18/14 dp en color; 14/10/8 dp en papel (aspecto de ficha impresa).

### 3.3 Movimiento (`ScMotion`)
| Microinteracción | Color | Papel / "Quitar animaciones" |
| :-- | :-- | :-- |
| Pulsar tarjeta o acción (`Pressable`) | Se hunde a 0,97–0,985 y rebota | Sin cambio |
| Cifras (`AnimatedMetricValue`) | Cuentan hasta el valor nuevo (650 ms) | Cambio en un fotograma |
| Barras y anillos | Avanzan con `easeOutCubic`; los anillos se llenan al aparecer | Sin animación |
| Entrada de pantalla (`Entrance`) | Bloques escalonados (12 px + fundido) | Aparecen tal cual |
| Barra inferior | Píldora tonal que se estira y cambia de pestaña | Contorno de tinta, sin transición |
| Páginas y hojas | `FadeForwards`, hoja con 340 ms | Instantáneas |
| Cambio de tema | Fundido de colores | Un solo refresco |

Los anillos que avanzan cada segundo (cronómetro de ayuno) no animan cambios (`animateChanges: false`) para no dibujar 60 fps de forma continua.

### 3.4 Rendimiento
* Barra inferior sólida: el desenfoque de fondo (`BackdropFilter`) se recalculaba en cada fotograma de desplazamiento.
* `RepaintBoundary` en anillos, barras, gráficas y barra de ayuno: un cronómetro o una animación no repintan la pantalla entera.
* Imágenes grandes decodificadas al tamaño mostrado (`ResizeImage`/`cacheWidth`): logo y foto de perfil. Nibi es vectorial (sin imágenes).
* `InkRipple` en lugar de `InkSparkle` (sin sombreador que compilar en el primer toque).
* El armazón de navegación solo se reconstruye si cambia la bandera del ayuno, no con cualquier cambio del perfil.
