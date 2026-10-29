# 10 · Privacidad, seguridad y pruebas

> Cómo se protege la información del usuario y cómo se verifica que la app funciona.

---

## 1. Verificación de Privacidad y Modelo de Amenazas Offline

NB Selfcare se concibe como un **Santuario Personal de Datos** (*Single-User Sanctuary*):

1. **Aislamiento de Red:**
   * La app no contiene ningún SDK de analítica, seguimiento, publicidad ni reporte de errores remoto.
   * La única llamada HTTP permitida en todo el código base es hacia la API pública de **Open Food Facts** (`https://world.openfoodfacts.org/api/v2/product/...`) cuando el usuario escanea un código de barras que no existe en el catálogo local.
   * `android:allowBackup="false"` garantiza que el archivo de base de datos nunca se replique de forma inadvertida a la nube de Google Drive mediante las copias de seguridad del sistema operativo.
2. **Cero Cuentas y Cero Identificadores Únicos:**
   * No existe inicio de sesión, correo electrónico ni identificadores persistentes vinculados a servidores remotos.
   * Todo identificador en SQLite es local y autoincremental.

---

3. **Excepción documentada: ML Kit** (ADR-13). El escáner y el OCR usan los modelos de ML Kit empaquetados en la app y funcionan sin conexión; ML Kit puede enviar a Google métricas técnicas anónimas de la API, nunca imágenes ni datos del usuario. Ningún otro SDK de Google se incluye.
4. **Datos en reposo:** la base de datos está en el almacenamiento privado de la app. Las copias de seguridad solo salen del teléfono cuando el usuario las comparte.
5. **Permisos mínimos y en contexto** (ver `07` §1.1): cada permiso se pide cuando se usa la función que lo necesita, nunca al abrir la app.

---

## 2. Pruebas (`test/`)

Unas 510 pruebas que se ejecutan con `flutter test` (≈ 6 min) y deben pasar también con otras zonas horarias (`TZ=America/Bogota`, `Europe/Madrid`, `Pacific/Chatham`).

| Carpeta | Qué cubre |
| :-- | :-- |
| `biometrics/`, `domain/`, `chronobiology/`, `protocol/` | Fórmulas (Katch-McArdle, US Navy, METs, EMA, falsa subida, TDEE adaptativo con su límite semanal), políticas de recompensa y racha, fases del ayuno, cafeína, protocolo semanal. |
| `database/`, `drift/` | DAOs, búsqueda FTS5 sin tildes, unicidad del libro de monedas, copias de seguridad de ida y vuelta con las 35 tablas, migraciones de cada versión a todas las posteriores. |
| `application/`, `health/`, `nutrition/` | Casos de uso: pesaje en cascada, comidas, agua, ayuno, informe, suplementos, sincronización con Health Connect. |
| `features/`, `pet/`, `accessibility/` | Pantallas: Inicio, Comida, Cuerpo, Nibi (coreografías, reacciones, respiración, tienda y armario), Perfil, bienvenida; guías de accesibilidad (tamaño de toque, etiquetas, contraste). |
| `design_system/` | Contraste AA de los 24 temas, movimiento desactivado en papel. |
| `qa_audit/` | Guardrails de arquitectura (`02` §7). |
| `edge_cases/` | Respuestas nativas imposibles, Open Food Facts caído o devolviendo basura, 50 000 tramas de báscula aleatorias, textos con emojis o inyección SQL, copias corruptas, cambios de horario y 29 de febrero, una simulación de 120 días de uso imperfecto, estrés de interfaz (24 temas, texto al 200 %, 320 px, tableta) y un "mono" que toca la app al azar. |

### Capturas

`flutter test tool/screenshots --update-goldens` siembra 30 días de datos realistas y genera una captura de cada pantalla en cuatro temas (Esmeralda Nocturna, Papel claro, Papel sepia y Salvia y Lino), además de estados de Nibi (respiración, tienda) y una galería de su dibujo (`nibi_gallery_test.dart`). Con `--dart-define=FULL_PAGE=true` captura la página completa.

### En el teléfono

Antes de cada versión se prueba en el TCL 50 Pro: bienvenida desde cero, permisos (concedidos y denegados), cronómetro del ayuno en la pantalla de bloqueo, recordatorios, Health Connect, báscula, escáner, dictado, copia de seguridad y TalkBack, con `flutter run` en depuración para ver cualquier aviso del framework.

**Limitación conocida (Flutter 3.47):** muy de vez en cuando, con un servicio de accesibilidad activo, el framework lanza un `Null check` interno en `_updateSemanticsNodeGeometry` al recalcular la semántica. No cierra la app (el fotograma siguiente se dibuja con normalidad) y no se pudo atribuir a ningún widget: en el teléfono, 300 toques al azar con la semántica activa no lo reprodujeron. Por eso el "mono" de las pruebas corre sin árbol de semántica y la accesibilidad se verifica aparte (`test/accessibility/`).
