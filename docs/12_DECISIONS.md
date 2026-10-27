# 12 · Registro de Decisiones de Arquitectura — ADRs (`docs/12_DECISIONS.md`)

> **Contexto:** Historial formal de decisiones técnicas, opciones descartadas y justificaciones de ingeniería que rigen el desarrollo de **NB Selfcare**.

---

### ADR-01: Bloques RPE de 5 Segundos sobre Registro Granular Serie por Serie
* **Contexto:** El registro tradicional de series, repeticiones y pesos en gimnasio toma 15–30 minutos por sesión y genera abandono masivo de la app.
* **Decisión:** Desacoplar el gasto pasivo (pasos NEAT leídos automáticamente de Health Connect) y permitir registrar entrenamientos intencionales en 5 segundos mediante `(Categoría, Duración, RPE)`.
* **Consecuencias:** Se calcula el gasto calórico neto por METs descontando el metabolismo basal y usando el último peso real de la báscula, eliminando la fricción de captura.

---

### ADR-02: Triángulo Electrolítico y Esenciales sobre Barras de 35 Micronutrientes Vacías
* **Contexto:** La mayoría de productos procesados con código de barras solo declaran 4 a 6 nutrientes en su etiqueta, dejando 30 barras en cero y creando falsas alarmas de deficiencia en el usuario.
* **Decisión:** Priorizar el triángulo electrolítico crítico (**Sodio, Potasio, Magnesio**) junto a Fibra, Hierro, Calcio, Zinc y Vitaminas clave (C, D, B12), diferenciando visualmente *"0 mg declarados"* de *"Dato no reportado"*.

---

### ADR-03: Inferencia Híbrida: SLM Local como Parser Sintáctico + SQLite FTS5 para Nutrientes
* **Contexto:** Los modelos de lenguaje pequeños (1.5B–3B) cuantizados a 4 bits tienden a alucinar calorías y densidades nutricionales exactas si se les pide inventar de memoria.
* **Decisión:** El modelo local actúa estrictamente como **extractor sintáctico** (convierte texto libre a un JSON con alimentos y gramos estimados). La aplicación luego cruza esos nombres contra la base de datos local verificada (`food_items_fts`).

---

### ADR-04: Lectura Directa BLE de 13 Bytes sobre Sincronización con Zepp Life
* **Contexto:** La app propietaria Zepp Life recorta la exportación a Health Connect y oculta métricas como agua corporal, grasa visceral, masa ósea y somatotipo.
* **Decisión:** Interceptar pasivamente la característica `0x2A9C` y los Service Data `0x181B` de la Xiaomi Mi Body Composition Scale 2, decodificando los 13 bytes en Dart y calculando localmente las 13 métricas completas sin abrir Zepp Life.

---

### ADR-05: Filosofía 100% Offline-First y Supresión de Backups en la Nube
* **Contexto:** Los datos de salud, peso, fotos de progreso y notas de diario constituyen la información más íntima del usuario y no deben filtrarse ni monetizarse.
* **Decisión:** Cero servidores remotos, cero Firebase, cero analytics y `android:allowBackup="false"`. La portabilidad y respaldo se garantizan mediante exportación e importación íntegra de un único archivo local `.sqlite` generado con `VACUUM INTO`.

---

### ADR-06: Cronómetro Nativo del Sistema Android sobre Foreground Service Pesado
* **Contexto:** Mantener un `ForegroundService` con un loop en Dart consumiendo batería constantemente solo para mostrar segundos de ayuno degrada la autonomía del dispositivo.
* **Decisión:** Utilizar la directiva nativa `setUsesChronometer(true)` de las notificaciones de Android. El reloj del sistema operativo actualiza la notificación en la pantalla de bloqueo con 0% de uso de CPU en segundo plano, promoviéndose a Live Update en Android 16.

---

### ADR-07: Santuario Personal de Datos (Single-User Sanctuary)
* **Contexto:** Las funciones sociales (redes de amigos, feeds públicos, tablas de clasificación) fomentan comparación tóxica y requieren backends en la nube.
* **Decisión:** NB Selfcare es estrictamente de un solo jugador. Todos los datos pertenecen a una sola persona y no existen botones de compartir en redes sociales.

---

### ADR-08: Gamificación Positiva y Escudos de Racha sobre Mecánicas Punitivas
* **Contexto:** Mecánicas tipo Tamagotchi donde la mascota enferma, muere o regaña al usuario generan ansiedad y culpa en momentos de estrés o enfermedad.
* **Decisión:** La mascota `Nibi` nunca muere ni emite reproches. La economía del juego es puramente positiva: se premia la constancia, el buen sueño otorga un multiplicador de $1.5\times$ en monedas, y se pueden comprar Escudos de Racha para proteger el progreso en vacaciones.

---

### ADR-09: Lienzo Procedural Nativo (`CustomPainter`) sobre Archivos Rive Externos
* **Contexto:** Depender obligatoriamente de un archivo binario `.riv` en disco provoca excepciones fatales si el archivo se corrompe o no existe en el primer arranque.
* **Decisión:** Implementar la mascota por defecto como un `CustomPainter` procedural en Flutter con interpolación de curvas y 60 fps nativos. El soporte para archivos `.riv` externos se mantiene como una capa opcional.
* **Estado (2026-10-26):** la implementación actual usa sprites PNG estáticos (`assets/images/nibi_sprites/`), que solo permiten cambiar de "sticker". Se reemplazará por una mascota animada (Rive empaquetado en `assets/` o `CustomPainter` esqueletal) en la fase final del plan de `15_AUDITORIA_AAA.md`. El riesgo original (archivo ausente) se mitiga empaquetando el `.riv` como asset y conservando un fallback estático.

---

### ADR-10: Fusión Antropométrica (60% BIA + 40% US Navy) para Recomposición Corporal
* **Contexto:** La bioimpedancia de pie a pie es sensible al estado de hidratación del tren inferior y puede registrar falsas subidas de grasa tras ingesta de agua o ejercicio.
* **Decisión:** Incorporar una validación quincenal con cinta métrica (Cintura y Cuello) aplicando la fórmula de la Marina de EE. UU., fusionando ambas señales para confirmar procesos reales de pérdida de grasa y recomposición corporal.

---

### ADR-11: Ventana Móvil de 14 Días con Acotamiento Semanal para el TDEE Adaptativo
* **Contexto:** Ajustar calorías diarias basándose en el peso de un solo día provoca oscilaciones drásticas debido a la retención hídrica y vaciado intestinal.
* **Decisión:** Evaluar el gasto energético real analizando la variación de la Media Móvil Exponencial ($\Delta\text{EMA}_{14\text{d}}$) frente al promedio de calorías consumidas en una ventana de 14 días ($\approx 7700\text{ kcal/kg}$), limitando el ajuste a un máximo de $\pm 150\text{ kcal}$ por semana.

---

### ADR-12: Motor Visual Dual por Hardware (Material You + NXTPAPER Anti-Ghosting)
* **Contexto:** Las pantallas de papel electrónico o modo tinta del TCL 50 Pro sufren de estelas grises (*ghosting*) ante transiciones animadas fluidas y sombras difusas.
* **Decisión:** Implementar un tema específico `nxtpaper_eink` con elevación cero, bordes sólidos de $1.5\text{ px}$, paleta blanco hueso/negro tinta y desactivación de animaciones de transición en gráficas (`Duration.zero`).


---

### ADR-13: ML Kit on-device para código de barras y OCR (excepción documentada a Zero-Telemetry)
* **Contexto:** `mobile_scanner` (Android) y `google_mlkit_text_recognition` usan Google ML Kit. Todo el procesamiento de imagen ocurre en el dispositivo, pero ML Kit envía a Google métricas anónimas de uso y rendimiento de la API. Las alternativas evaluadas son zxing-cpp (`flutter_zxing`) para códigos y Tesseract para OCR.
* **Criterio del dueño del producto:** solo se cambia una pieza si la alternativa funciona igual o mejor; el escáner de códigos y la consulta a Open Food Facts no pueden degradarse.
* **Decisión:** se mantiene ML Kit para ambos casos. zxing-cpp es competitivo en EAN-13 bien iluminado pero inferior en ángulos, desenfoque y poca luz; Tesseract es claramente inferior a ML Kit leyendo tablas nutricionales.
* **Consecuencias:**
  * Ninguna imagen, código escaneado ni dato del usuario sale del dispositivo por ML Kit; solo métricas técnicas de la API.
  * Ningún otro SDK de Google o de terceros puede añadirse amparándose en esta excepción.
  * Si aparece una alternativa sin telemetría con calidad equivalente, se reabre esta decisión.
