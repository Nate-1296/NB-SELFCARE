# NB Selfcare (`com.nb.selfcare`)

> **Centro Autónomo de Autocuidado, Biometría, Nutrición e IA Local.**  
> Diseñado bajo la filosofía **100% Offline-First**, cero telemetría, cero cuentas en la nube, optimizado para el **TCL 50 Pro NXTPAPER** (Android 16 API 36) y lectura directa por Bluetooth de la **Xiaomi Mi Body Composition Scale 2**.

---

## 🌟 Características Principales

* 🔒 **Santuario 100% Offline-First:** Toda tu información vive en `nb_selfcare.sqlite` en tu propio dispositivo. Cero cuentas, cero servidores externos, cero telemetría y portabilidad absoluta con exportación e importación atómica del archivo de base de datos.
* 📱 **Hardware Específico y Modo Visual Dual:**
  * **Material You:** Paleta dinámica basada en Android 16 con Dynamic Color.
  * **Modo Papel E-Ink NXTPAPER:** Cero sombras difusas, bordes sólidos de $1.5\text{ px}$, paleta blanco hueso/negro tinta y desactivación de animaciones de transición en gráficas para eliminar por completo el efecto estela (*ghosting*) en pantallas de papel electrónico.
* ⚖️ **Báscula Xiaomi Mi Scale 2 sin Intermediarios:** Lectura pasiva de los anuncios Bluetooth GATT (`0x181B` / `0x2A9C`) de la Xiaomi Mi Body Composition Scale 2 (`XMTZC05HM`). Decodifica en vivo la trama de 13 bytes y calcula las **13 métricas corporales completas** (Peso, IMC, % Grasa, Masa Muscular, % Agua, Grasa Visceral, Masa Ósea, % Proteína, TMB Katch-McArdle, Edad Metabólica, Masa Magra, Puntaje Corporal y Somatotipo) sin abrir Zepp Life.
* 🌉 **Puente de Salud con Android 16 Health Connect:** Sincronización bidireccional integrada con el framework del sistema operativo para pasos (NEAT), sueño con fases (REM y Profundo), frecuencia cardíaca en reposo, hidratación, peso y grasa corporal.
* 🥗 **Nutrición sin Fricción (< 15 Segundos):**
  * **Escáner EAN-13:** Búsqueda ultrarrápida en caché local y consulta con guardado automático de **Open Food Facts**.
  * **Semilla USDA en Español:** Catálogo offline de alimentos naturales con desglose exacto de macronutrientes y el **Triángulo de Electrolitos (Sodio, Potasio, Magnesio)**, además de Fibra, Hierro, Calcio, Zinc y Vitaminas clave.
  * **Combos Caseros con Escalador:** Barra deslizadora de multiplicador ($0.25\times\text{–}3.0\times$) para escalar raciones completas en un solo toque.
  * **Botón "Repetir comida de ayer"** por bloque horario con opción de deshacer.
  * **Dictado por Voz y Texto:** Reconocimiento de voz local y extracción de porciones con IA en el dispositivo.
* ⏱️ **Entrenamiento RPE en 5 Segundos:** Separación estricta entre el movimiento cotidiano pasivo (pasos NEAT de Health Connect) y el ejercicio intencional por bloques de Categoría + Minutos + Esfuerzo Percibido (RPE), calculando las calorías netas con el último peso real de la báscula.
* 🧬 **Inteligencia Biométrica Local:**
  * **Edad Dinámica:** Calculada al vuelo desde tu fecha de nacimiento.
  * **Peso Tendencia (EMA $\alpha = 0.1$):** Suavizado de oscilaciones hídricas diarias.
  * **Detector de Falsa Subida:** Diagnóstico fisiológico tranquilizador cuando el peso sube por retención de agua/glucógeno (cruzando sodio, carbohidratos o BIA) en lugar de grasa.
  * **TDEE Adaptativo (Ventana Móvil de 14 Días):** Auto-calibra tu gasto calórico real según el balance energético y la pendiente del peso tendencia.
  * **Validación Antropométrica Quincenal:** Fusión ponderada de bioimpedancia y cinta métrica (Cintura y Cuello con fórmula US Navy) para confirmar recomposición corporal.
* 🐾 **Ayuno, Mascota Virtual y Gamificación Positiva:**
  * **Temporizador de Ayuno en Pantalla de Bloqueo:** Notificación nativa con `Chronometer` del sistema (0% de CPU en background y Live Update en Android 16) con línea de tiempo de fases metabólicas (anabólica, glucogenólisis, quema de grasa, cetosis y autofagia).
  * **Diario Privado con Fotos Locales:** Análisis local de ánimo, energía y estrés con motor estadístico de correlaciones cruzadas (sueño vs. grasa, estrés vs. calorías).
  * **Mascota Virtual Procedural (`Nibi`):** Lienzo nativo a 60 fps que reacciona a tu estado de hidratación, cetosis, pesaje en vivo y sueño.
  * **Economía Positiva:** Multiplicador de $1.5\times$ en recompensas por cumplir tu meta de sueño, tienda de accesorios y **Escudos de Racha** para proteger tu progreso durante vacaciones o días libres.
  * **Gestor de IA Local Eficiente:** Carga perezosa de modelos cuantizados (Qwen / Gemma) en GPU con apagado automático tras 120 segundos de inactividad para proteger la RAM.

---

## 📚 Índice de Especificaciones Técnicas (`docs/`)

| Documento | Descripción y Contenido |
| :-- | :-- |
| [**01 · Especificación de Producto**](docs/01_PRODUCT_SPEC.md) | Visión, principios inquebrantables, especificación pantalla por pantalla y matriz de alcance. |
| [**02 · Arquitectura del Sistema**](docs/02_ARCHITECTURE.md) | Capas del sistema, topología de directorios, flujo reactivo y gestión de dependencias. |
| [**03 · Base de Datos Relacional**](docs/03_DATABASE_SPEC.md) | Esquema de las 14 tablas en Drift, triggers FTS5 y exportación atómica `VACUUM INTO`. |
| [**04 · Biometría y Báscula BLE**](docs/04_BIOMETRICS_AND_SCALE.md) | Trama de 13 bytes GATT, derivación de 13 métricas, EMA, detector de retención y TDEE adaptativo. |
| [**05 · Motor de Nutrición**](docs/05_NUTRITION_ENGINE.md) | Escáner Open Food Facts, base USDA en español, combos caseros, semáforo de electrolitos y agua. |
| [**06 · Entrenamiento RPE y NEAT**](docs/06_WORKOUT_AND_NEAT.md) | Captura de entrenamiento en 5 segundos, tabla oficial de METs y gasto calórico neto. |
| [**07 · Android 16 y Modo NXTPAPER**](docs/07_ANDROID16_AND_NXTPAPER_UI.md) | Permisos API 36, Health Connect nativo y motor visual de alto contraste para TCL 50 Pro. |
| [**08 · IA Local y Gamificación**](docs/08_LOCAL_AI_AND_GAMIFICATION.md) | Gestión de memoria GPU (TTL 120s), prompts deterministas, lienzo procedural de Nibi y CoinLedger. |
| [**09 · Ayuno, Diario y Analítica**](docs/09_FASTING_JOURNAL_ANALYTICS.md) | Fases fisiológicas de ayuno, cronómetro en pantalla de bloqueo y correlaciones cruzadas. |
| [**10 · Seguridad y Pruebas**](docs/10_SECURITY_AND_TESTING.md) | Auditoría de aislamiento de red y batería de pruebas unitarias para algoritmos fisiológicos. |
| [**11 · Plan de Ejecución y Roadmap**](docs/11_ROADMAP.md) | Desglose modular de desarrollo en 6 fases secuenciales. |
| [**12 · Registro de Decisiones (ADRs)**](docs/12_DECISIONS.md) | Historial formal de decisiones de diseño técnico (ADR-01 a ADR-12). |
| [**Instrucciones para Agentes (AGENTS.md)**](AGENTS.md) | Guía técnica y guardrails estrictos para asistentes de código y desarrolladores. |

---

## 🛠️ Requisitos y Toolchain

* **SDK:** Flutter 3.47+ / Dart 3.13+ (ver `.fvmrc`).
* **Android Target:** Android 16 (API 36).
* **Base de Datos:** SQLite 3.45+ con módulo FTS5 y `store_date_time_values_as_text: true`.
