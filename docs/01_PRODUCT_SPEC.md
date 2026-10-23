# 01 · Especificación de Producto (`docs/01_PRODUCT_SPEC.md`)

> **Fuente de verdad funcional.** Define el *qué* y el *para qué* de **NB Selfcare** (`com.nb.selfcare`). El *cómo* está en los documentos 02–10; las decisiones y sus porqués en [`12_DECISIONS.md`](12_DECISIONS.md). Si un documento técnico contradice a este, gana este documento y se corrige el otro.

---

## 1. Visión

**NB Selfcare** es un sistema autónomo de gestión biométrica, nutricional, metabólica, conductual y de gamificación positiva que consolida y reemplaza, en un único binario local, las funciones de pago de **MyFitnessPal Premium, Cronometer Gold, MacroFactor, BitePal Pro, Zero Fasting, Zepp Life, Samsung Health y Google Fit**.

* **Usuario objetivo:** una sola persona (el dueño del teléfono). *Single-User Sanctuary*.
* **Dispositivo de referencia:** **TCL 50 Pro NXTPAPER** con **Android 16 (API 36)** + báscula **Xiaomi Mi Body Composition Scale 2 (`XMTZC05HM`)**.
* **Idioma:** español latinoamericano (UI 100% localizable vía ARB para que la comunidad añada idiomas).

## 2. Principios inquebrantables (Core Tenets)

| # | Principio | Implicación verificable |
| :-: | :-- | :-- |
| 1 | **100% Offline-First, Zero-Cloud, Zero-Telemetry** | Toda la persistencia vive en `nb_selfcare.sqlite`. Cero cuentas, cero Firebase/analytics/crash reporters remotos, `android:allowBackup="false"` (ni siquiera Google Drive Backup). La red solo se usa para: (a) consulta opcional a **Open Food Facts** al escanear un código no cacheado, (b) descarga opcional, iniciada por el usuario, de pesos de modelos LLM. Cualquier otra llamada de red es un bug. |
| 2 | **Portabilidad total** | Exportación íntegra a un único archivo `.sqlite` (incluye fotos de progreso como BLOB) e importación con validación. El archivo es legible por herramientas estándar (fechas ISO-8601). |
| 3 | **Fricción mínima (Regla < 15 s)** | Ningún flujo de captura (comida, agua, pesaje, entrenamiento, diario) supera 15 s ni exige formularios multipaso. Ver §5. |
| 4 | **Cascada biométrica reactiva** | La BD es un grafo reactivo: un pesaje nuevo o un cambio de día recalcula en cascada edad, IMC, TMB, Peso Tendencia, TDEE, metas, detector de retención, recompensas y estado de la mascota, sin botón "recalcular". |
| 5 | **Motor visual dual por hardware** | **Material You** (`dynamic_color`) + **Modo Papel NXTPAPER** (cero sombras, bordes sólidos 1.5 px, alto contraste, codificación independiente del color, cero animaciones superfluas → sin estelas/ghosting). |
| 6 | **Positividad radical** | Cero mecánicas punitivas, cero lenguaje de culpa. La mascota nunca muere ni enferma. |
| 7 | **Degradación elegante** | Todo lo que usa IA local, Health Connect, BLE o red tiene un camino determinista que funciona sin ello. |

## 3. Navegación

`NavigationBar` Material 3 con **5 destinos** + acciones rápidas modales (`BottomSheet` de 1 toque):

| Tab | Pantalla | Ruta (`go_router`) |
| :-: | :-- | :-- |
| 1 | Inicio — Hábitat y Centro de Mando | `/` |
| 2 | Nutrición e Hidratación | `/nutrition` |
| 3 | Cuerpo, Báscula y Movimiento | `/body` |
| 4 | Ayuno y Cronobiología | `/fasting` |
| 5 | Diario, Analítica y Perfil | `/journal` |

Rutas fuera del shell: `/onboarding`, `/settings`, `/settings/backup`, `/settings/ai`, `/shop`, `/health-connect/rationale` (política de privacidad exigida por Health Connect).

> Las tabs se habilitan a medida que cada fase del roadmap se completa (feature flags en código); nunca se muestran pantallas vacías o "próximamente".

---

## 4. Especificación página por página

### Página 1 · Dashboard Central — "El Hábitat y Centro de Mando" (`DashboardScreen`)

Vista raíz suscrita al stream maestro `watchTodayDashboard(dateKey)`.

* **Hábitat de la mascota (`PetHabitatWidget`)** — lienzo `ProceduralPetCanvas` (CustomPainter; Rive opcional en el futuro, ver ADR-09) que reacciona a: ayuno en curso ≥ 12 h (`isFastingKetosis`), `hydrationRatio`, `sleepQuality` (Health Connect), pesaje BLE en vivo (`isWeighingIn`) y `coinsBalance`. En Modo Papel la animación es de bajo movimiento (redibujo solo ante cambios de estado).
  * **Burbuja de diálogo (`PetDialogueBubble`):** mensaje contextual generado por el SLM local, o banco de frases determinista si la IA está desactivada.
* **Anillos (`MacroRingsCard`):** anillo principal de **Calorías Restantes** = $\text{Meta del día} - \text{Consumidas}$, donde la meta del día ya incluye ejercicio neto y ajuste NEAT (ver `04_BIOMETRICS_AND_SCALE.md` §7). Secundarios: Proteína, Carbohidratos, Grasa (g).
* **Bento Grid de estado (`BentoStatusGrid`):**
  * **Hidratación:** ml vs meta + botones `+250 ml`, `+500 ml`, vaso personalizado.
  * **Ayuno:** cronómetro en vivo + fase metabólica actual (misma fuente que la notificación persistente).
  * **Sueño y Pasos (Health Connect):** horas dormidas con desglose REM/Profundo + pasos (NEAT).
  * **Peso y Tendencia:** último peso vs **Peso Tendencia (EMA)** con $\Delta$ kg semanal.
* **Dock de acción rápida (1 toque):** Escanear código · Dictar comida · Pesarme · Bloque de ejercicio.

### Página 2 · Nutrición, Micronutrientes e Hidratación (`NutritionScreen`)

Diseñada para superar a MyFitnessPal Premium y Cronometer Gold sin fricción. Detalle técnico: [`05_NUTRITION_ENGINE.md`](05_NUTRITION_ENGINE.md).

* **Flujo 1 — Escáner de código de barras (`BarcodeScannerModal`):** EAN-13/EAN-8/UPC-A/UPC-E con decodificador local (zxing-cpp, sin Google Play Services). Busca primero en `food_items.barcode`; si no existe consulta **Open Food Facts**, normaliza a 100 g, guarda `nutriScore`, persiste en SQLite + FTS5 y abre el selector de porción. Si no hay red o el producto no existe → alta manual rápida (4 macros + sodio opcional) asociada a ese código.
* **Flujo 2 — Dictado por voz/texto con IA local (`AiMealParserSheet`):** *"200 g de pechuga a la plancha, media taza de arroz y un aguacate pequeño"*. Voz → texto con el reconocedor **on-device** de Android (nunca en la nube). El SLM solo **estructura** (JSON de alimentos + gramos); los nutrientes salen de la BD local (ADR-03). Siempre se muestra una hoja de revisión editable antes de guardar.
* **Flujo 3 — Combos con escalador (`MealCombosWidget`):** agrupa alimentos en un `MealCombo`; al registrar, `Slider` continuo de $0.25\times$ a $3.0\times$ con paradas rápidas en $0.5\times$, $0.75\times$, $1\times$, $1.5\times$ que escala gramos, kcal, macros y micronutrientes. "Guardar como combo" desde cualquier comida ya registrada.
* **"Repetir comida de ayer"** por bloque (`breakfast`, `lunch`, `dinner`, `snack`) en 1 toque, con *Deshacer*.
* **Panel de micronutrientes (`MicronutrientTrafficLight`):** prioriza el **triángulo electrolítico Sodio–Potasio–Magnesio**, más **Fibra, Hierro, Calcio, Zinc y Vitaminas C, D, B12**, con metas por sexo/edad e indicador de **cobertura de datos** (los "sin dato" nunca se pintan como cero; ADR-02).
* **Hidratación:** vasos rápidos; cada vaso es un registro (editable/borrable) que se exporta a Health Connect.

### Página 3 · Laboratorio Corporal, Báscula BLE y Movimiento (`BodyAndWorkoutScreen`)

Detalle técnico: [`04_BIOMETRICS_AND_SCALE.md`](04_BIOMETRICS_AND_SCALE.md).

* **Pesaje en vivo (`LiveWeighInModal` + `XiaomiMiScale2Driver`):** escaneo BLE pasivo de los anuncios de la báscula (Service Data `0x181B`, trama de 13 bytes) **sin abrir Zepp Life**. Muestra el peso fluctuando (la mascota sube a su mini báscula), detecta estabilización e impedancia y calcula las **13 métricas**: Peso, IMC, % Grasa, Masa Muscular, % Agua, Grasa Visceral, Masa Ósea, % Proteína, TMB, Edad Metabólica, Masa Magra, Puntaje Corporal (0–100) y Somatotipo. Escribe peso y % grasa en Health Connect.
  * **Filtro de invitado:** si el peso difiere > 8% de la tendencia, pregunta "¿Eres tú?" (la báscula también pesa a otras personas).
  * **Modo sin impedancia:** opción de perfil para portadores de marcapasos/implantes o embarazo → solo peso (ver §6).
* **Gráfica dual (`WeightTrendChart`):** puntos de peso diario vs línea de **Peso Tendencia (EMA)**.
* **Detector de "Falsa Subida" (`WaterRetentionAlert`):** si el peso sube ≥ 0.4 kg en un día y hay sodio alto, supercompensación de glucógeno o subida de agua por BIA, muestra un mensaje tranquilizador explicando que es agua/glucógeno, no grasa.
* **Validación con cinta métrica (`TapeMeasureCheckCard`):** cada **14 días** (mismo día de la semana que la calibración del TDEE) pide solo **cintura y cuello** (+ cadera en sexo biológico femenino). Calcula % grasa US Navy y el `validatedBodyFatPercentage` (60% BIA + 40% cinta) para detectar **recomposición corporal**.
* **Entrenamiento en 5 segundos (`QuickRpeWorkoutSheet`):** el **NEAT** (pasos de Health Connect) va separado del ejercicio intencional. Tres selectores, sin series ni repeticiones:
  1. **Categoría:** Pesas/Fuerza · Calistenia/Funcional · Cardio · Deporte.
  2. **Duración:** 10–180 min.
  3. **Esfuerzo (RPE):** Ligero · Moderado · Intenso.

  Calcula **calorías netas** (descontando el reposo) con el **último peso real** de la báscula.

### Página 4 · Ayuno y Cronobiología (`FastingAndAlarmsScreen`)

Detalle técnico: [`09_FASTING_JOURNAL_ANALYTICS.md`](09_FASTING_JOURNAL_ANALYTICS.md).

* **Protocolos:** `16:8`, `18:6`, `20:4`, `OMAD 23:1` y libre.
* **Línea de tiempo metabólica:** Anabólica (0–4 h) · Catabólica/glucogenólisis (4–12 h) · Quema de grasa (12–18 h) · Cetosis (18–24 h) · Autofagia profunda (> 24 h). Contenido educativo con descargo.
* **Temporizador en pantalla de bloqueo:** notificación persistente con `Chronometer` nativo del sistema (cero CPU en segundo plano); en Android 16 se promueve a **Live Update** (chip en barra de estado). Sin Foreground Service (ADR-06).
* **Alertas de electrolitos** en ayunos > 16 h (Na/K/Mg) y aviso de seguridad en ayunos > 24 h.
* **Recordatorios (`ReminderScheduler`):** hidratación, apertura/cierre de ventana de alimentación, pesaje matutino en ayunas, cinta métrica cada 14 días, diario. Alarmas exactas si el usuario concede `SCHEDULE_EXACT_ALARM`; si no, inexactas (degradación elegante).

### Página 5 · Diario, Analítica Cruzada y Perfil Vivo (`JournalAnalyticsProfileScreen`)

* **Diario privado (`PrivateJournalView`):** texto libre + foto de progreso opcional (guardada dentro del `.sqlite`). Al guardar, el SLM local extrae en segundo plano `moodScore`, `energyLevel`, `stressLevel` (1–5), hasta 3 etiquetas y un resumen empático. Sin IA: selectores rápidos de ánimo/energía/estrés + etiquetado por diccionario.
* **Motor de correlaciones (`CrossAnalyticsEngine`):** tarjetas de hallazgos con significancia mínima: Sueño ↔ Apetito/Pérdida de grasa · Estrés ↔ Calorías · Cumplimiento de ayuno ↔ Tendencia de peso. Lenguaje de "posible relación", nunca causal.
* **Perfil vivo (`LivingProfileSection`):** edad exacta calculada al vuelo desde `birthDate`; **TDEE adaptativo** recalibrado cada 14 días con historial visible; metas de macros derivadas.
* **Tienda de la mascota (`PetShopScreen`):** accesorios, fondos y **Escudos de Racha** (+ modo vacaciones).
* **Ajustes:** tema (Material You / Modo Papel, claro/oscuro/sistema), gestor de modelos IA (importar `.task`/`.litertlm`/`.gguf`, TTL de memoria 120 s), Health Connect, báscula, recordatorios, **Exportar/Importar `.sqlite`**.

---

## 5. Presupuesto de fricción (Regla < 15 s)

| Flujo | Toques objetivo | Tiempo objetivo |
| :-- | :-: | :-: |
| Vaso de agua | 1 | < 2 s |
| Repetir comida de ayer | 1 (+ deshacer) | < 3 s |
| Combo habitual con escalador | 2–3 | < 6 s |
| Bloque de ejercicio RPE | 3–4 | < 5 s |
| Escanear producto cacheado | 2–3 | < 8 s |
| Dictado IA de comida (modelo cargado) | 3–4 | < 15 s |
| Pesaje BLE | 1 (abrir modal) + subirse | < 15 s |
| Entrada de diario corta | 2 + texto | < 15 s |
| Validación cinta (cada 14 d) | 3 campos | < 15 s |

Toda acción de registro ofrece **Deshacer** (SnackBar) y edición/borrado posterior.

---

## 6. Seguridad, salud y descargo

* NB Selfcare **no es un dispositivo médico**. Las métricas de bioimpedancia son estimaciones; las fases del ayuno son orientativas.
* **Onboarding** incluye un descargo y preguntas de seguridad: embarazo, marcapasos/implantes electrónicos (→ desactiva impedancia; la propia Xiaomi lo contraindica), historial de trastornos de la conducta alimentaria (→ oculta conteo agresivo de déficit y desactiva protocolos de ayuno > 16 h por defecto), diabetes/medicación hipoglucemiante (→ aviso antes de ayunar).
* Pisos de seguridad de calorías y ritmo máximo de pérdida (ver `04` §7). Nunca se recomienda < TMB.

---

## 7. Matriz de alcance estricto (Guardrail)

> **Para agentes de IA:** no implementes código, dependencias ni pantallas de la columna derecha.

| ✅ SÍ hace (In-Scope) | ❌ NO hace (Out-of-Scope / Prohibido) |
| :-- | :-- |
| **Persistencia 100% local en SQLite (Drift)** con backups completos exportables por el usuario. | **Cero cuentas en la nube, Firebase, Supabase o backends remotos**; cero telemetría/analytics/crash reporting remoto; cero Google Drive Auto Backup. |
| **Lectura BLE directa de la Xiaomi Mi Body Composition Scale 2 (`XMTZC05HM`)** + contrato abstracto `BodyScaleDriver` para PRs de la comunidad. | **No codificar drivers para decenas de marcas** (otras marcas entran vía Health Connect o vía PR comunitario que implemente el contrato). |
| **Sincronización bidireccional con Health Connect** (lee sueño+fases, pasos, FC en reposo, peso, grasa, hidratación; escribe peso, grasa, hidratación). | **No integrar SDKs privados/deprecados** (Google Fit REST, SDK de Samsung Health o Zepp). |
| **Entrenamiento en 5 s por bloques (Categoría + Minutos + RPE)**. | **No hay tracker serie-por-serie ni catálogo de 500 máquinas**. |
| **Inferencia LLM 100% en el dispositivo** (LiteRT / llama.cpp) con degradación elegante. | **No depender de APIs de IA de pago en la nube**. |
| **Gamificación positiva por constancia** y Escudos de Racha comprables. | **Cero mecánicas punitivas** (la mascota no muere, no enferma, no regaña). |
| **Privacidad absoluta de un solo usuario**. | **Cero funciones sociales** (amigos, feeds, rankings, compartir en redes). |
| Español LatAm, UI localizable. | iOS, web y escritorio (no soportados en v1). |

