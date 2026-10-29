# 11 · Decisiones de arquitectura (ADR)

> Decisiones técnicas, alternativas descartadas y su porqué. Una decisión solo se reabre con una alternativa igual o mejor.

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

### ADR-03: Analizador determinista + FTS5 para el texto de comidas (sin modelo de lenguaje)
* **Contexto:** El plan original usaba un modelo de lenguaje local (1,5B–3B) para estructurar el texto. Ningún runtime estaba integrado y un modelo así pesa más de 1 GB, tarda en cargar y puede inventar cantidades.
* **Decisión (2026-10-26, dueño del producto):** se retira la promesa de "IA" de la app. `TextAssistant` usa reglas deterministas (cantidades, unidades caseras, separadores) y el catálogo local con FTS5; los nutrientes salen siempre de la base de datos, nunca de una estimación libre.
* **Consecuencias:** resultado instantáneo, sin descargas y 100 % testeable (`text_parsing_fuzz_test`). Si en el futuro se integra un modelo local, solo podrá actuar como extractor sintáctico sobre el mismo contrato (`ParsedMealItem`).

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
* **Estado:** implementado (`lib/features/pet_gamification/presentation/nibi/`): 11 actividades, reacciones, cosméticos y escenarios dibujados en código; en Modo Papel, pose fija con paleta de tinta. No se añadió Rive: no hace falta ninguna dependencia ni archivo binario. Detalle en [`08`](08_NIBI_AND_REWARDS.md).

---

### ADR-10: Fusión Antropométrica (60% BIA + 40% US Navy) para Recomposición Corporal
* **Contexto:** La bioimpedancia de pie a pie es sensible al estado de hidratación del tren inferior y puede registrar falsas subidas de grasa tras ingesta de agua o ejercicio.
* **Decisión:** Incorporar una validación quincenal con cinta métrica (Cintura y Cuello) aplicando la fórmula de la Marina de EE. UU., fusionando ambas señales para confirmar procesos reales de pérdida de grasa y recomposición corporal.

---

### ADR-11: Ventana Móvil de 14 Días con Acotamiento Semanal para el TDEE Adaptativo
* **Contexto:** Ajustar calorías diarias basándose en el peso de un solo día provoca oscilaciones drásticas debido a la retención hídrica y vaciado intestinal.
* **Decisión:** Evaluar el gasto energético real analizando la variación de la Media Móvil Exponencial ($\Delta\text{EMA}_{14\text{d}}$) frente al promedio de calorías consumidas en una ventana de 14 días ($\approx 7700\text{ kcal/kg}$), limitando el ajuste a un máximo de $\pm 150\text{ kcal}$ por semana.

---

### ADR-12: Dos modos visuales: color y papel (anti-*ghosting*)
* **Contexto:** Las pantallas de papel electrónico o en modo tinta del TCL 50 Pro dejan estelas grises (*ghosting*) con transiciones animadas y sombras difusas.
* **Decisión:** Un catálogo de temas donde cada uno declara si es de papel (`ScColors.isFlat`). En papel: elevación cero, filetes de 1,5 px, esquinas más rectas y **ningún movimiento** (`ScMotion` devuelve duración cero; Nibi y los escenarios no tienen ticker).
* **Consecuencias:** cualquier widget nuevo debe leer los tokens del tema y `ScMotion`; `motion_test` y `theme_catalog_test` lo vigilan.

---

### ADR-13: ML Kit on-device para código de barras y OCR (excepción documentada a Zero-Telemetry)
* **Contexto:** `mobile_scanner` (Android) y `google_mlkit_text_recognition` usan Google ML Kit. Todo el procesamiento de imagen ocurre en el dispositivo, pero ML Kit envía a Google métricas anónimas de uso y rendimiento de la API. Las alternativas evaluadas son zxing-cpp (`flutter_zxing`) para códigos y Tesseract para OCR.
* **Criterio del dueño del producto:** solo se cambia una pieza si la alternativa funciona igual o mejor; el escáner de códigos y la consulta a Open Food Facts no pueden degradarse.
* **Decisión:** se mantiene ML Kit para ambos casos. zxing-cpp es competitivo en EAN-13 bien iluminado pero inferior en ángulos, desenfoque y poca luz; Tesseract es claramente inferior a ML Kit leyendo tablas nutricionales.
* **Consecuencias:**
  * Ninguna imagen, código escaneado ni dato del usuario sale del dispositivo por ML Kit; solo métricas técnicas de la API.
  * Ningún otro SDK de Google o de terceros puede añadirse amparándose en esta excepción.
  * Si aparece una alternativa sin telemetría con calidad equivalente, se reabre esta decisión.

---

### ADR-14: Equipos declarados: lo que no se tiene, no aparece
* **Contexto:** la 1.0 daba por hecho el hardware de referencia (TCL NXTPAPER y Mi Scale 2). Para cualquier otra persona, los modos de papel y la estación de báscula eran ruido.
* **Decisión:** el perfil guarda los equipos (`has_eink_screen`, `has_smart_scale`, `vital_devices_json`), preguntados en la bienvenida (el modelo del teléfono solo propone la respuesta) y editables en Ajustes → Tus equipos. Sin papel no se ofrecen esos temas (y se sale de uno si estaba activo); sin báscula, Cuerpo usa peso a mano, IMC, metabolismo basal y cinta; sin aparato, no hay signos vitales.
* **Consecuencias:** la migración 6 → 7 marca báscula y papel en perfiles existentes para no quitarle nada a quien ya usaba la app.

---

### ADR-15: Sexta pestaña "Cuidado" en vez de sobrecargar las existentes
* **Contexto:** ocho apartados nuevos (tratamientos, hábitos, suelo pélvico, pausas, signos vitales, síntomas, chequeos, alcohol y tabaco) no caben en Inicio, Cuerpo ni Perfil sin romper "una acción principal por bloque".
* **Decisión:** una pestaña propia entre Cuerpo y Nibi. Cada apartado se activa o desactiva (Ajustes → Módulos); Inicio solo recibe una tarjeta resumen. Suplementos y digestión salen de Perfil y viven aquí.
* **Consecuencias:** la barra inferior pasa a seis destinos (indicador algo más estrecho, etiquetas que se ajustan). Si una persona apaga todos los apartados, la pestaña lo dice y enlaza a Ajustes.

---

### ADR-16: Health Connect: leer signos vitales, escribir solo respiración
* **Contexto:** tensiómetros, glucómetros y oxímetros escriben en Health Connect. Pedir todos los permisos a todo el mundo contradice la mínima exposición.
* **Decisión:** se pide la lectura de cada signo vital solo al declarar su aparato, aparte del permiso base. Las lecturas se guardan con su id de Health Connect (sin duplicados) y se validan (rango plausible). Las sesiones de respiración se escriben como `MindfulnessSession` solo si el proveedor lo soporta. Las mediciones manuales no se exportan.
* **Consecuencias:** sin Health Connect todo funciona a mano (degradación elegante). Rangos orientativos (AHA 2017, ADA, OMS), nunca diagnóstico.

---

### ADR-17: Medicamentos sin monedas, avisos discretos y "Hecho" desde la notificación
* **Contexto:** un aviso de medicación en la pantalla de bloqueo revela datos de salud; gamificar un tratamiento puede hacer sentir culpa por una toma olvidada.
* **Decisión:** los avisos de tomas son discretos por defecto (sin nombre) y privados en la pantalla de bloqueo; llevan un botón "Hecho" que guarda la acción en el teléfono y se aplica al abrir la app. Las tomas no dan monedas; los hábitos, el suelo pélvico, las pausas y los chequeos sí. Las bebidas alcohólicas se registran también en Comida para que su energía cuente en el balance y en el gasto adaptativo.
* **Consecuencias:** marcar una toma desde la notificación no requiere abrir la app ni red; la reserva se descuenta al marcar y se devuelve al deshacer.

