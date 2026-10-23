# 09 · Ayuno Intermitente, Diario Privado y Analítica Cruzada (`docs/09_FASTING_JOURNAL_ANALYTICS.md`)

> **Contexto Técnico:** Temporizador de ayuno intermitente con fases metabólicas y cronómetro nativo en pantalla de bloqueo, diario privado con fotos locales y motor estadístico de correlaciones cruzadas.

---

## 1. Motor de Ayuno Intermitente y Fases Metabólicas

NB Selfcare implementa un temporizador de alta eficiencia que no mantiene procesos activos en segundo plano:

* **Protocolos Predeterminados:**
  * `16:8` (Estándar Leangains / Inicio).
  * `18:6` (Quema acelerada de grasa).
  * `20:4` (La Dieta del Guerrero).
  * `OMAD 23:1` (Una comida al día).
  * `Custom` (Objetivo personalizado o modo libre).

### Línea de Tiempo Fisiológica

La interfaz mapea la hora actual del ayuno con la transición bioquímica real:

| Intervalo | Fase Metabólica | Marcador Fisiológico |
| :-- | :-- | :-- |
| **$0\text{–}4\text{ h}$** | **Fase Anabólica** | Digestión, absorción de glucosa y aminoácidos, insulina elevada. |
| **$4\text{–}12\text{ h}$** | **Fase Catabólica / Glucogenolítica** | Caída de insulina a nivel basal; degradación de glucógeno hepático para mantener normoglucemia. |
| **$12\text{–}18\text{ h}$** | **Lipólisis y Transición Cetogénica** | Agotamiento del glucógeno hepático; activación de lipasa sensible a hormonas y beta-oxidación de ácidos grasos. Se activa el aura en la mascota `Nibi`. |
| **$18\text{–}24\text{ h}$** | **Cetosis Activa** | Producción hepática de cuerpos cetónicos ($\beta$-hidroxibutirato y acetoacetato). |
| **$> 24\text{ h}$** | **Autofagia Profunda** | Reciclaje lisosomal de orgánulos y proteínas dañadas. *Aviso de seguridad y recordatorio de electrolitos (Na, K, Mg)*. |

### Notificación Persistente con Cero Consumo de CPU

Para no agotar la batería del usuario, la notificación en pantalla de bloqueo utiliza la directiva nativa del sistema Android:
```dart
NotificationCompat.Builder(context, CHANNEL_FASTING)
    .setUsesChronometer(true)
    .setChronometerCountDown(false)
    .setWhen(sessionStartedAtTimestamp)
    .setOngoing(true)
```
El propio sistema operativo Android actualiza los segundos en pantalla sin necesidad de que la aplicación esté en memoria ni despierte hilos de CPU. En **Android 16**, esto se promueve a un chip de estado (*Live Update*).

---

## 2. Diario Privado y Metadatos Locales

* **Entrada de Texto Libre:** Para registrar reflexiones, sensaciones de energía, comidas fuera de casa o eventos de vida.
* **Foto de Progreso Físico:** Almacenada en la carpeta privada de la aplicación (o como BLOB en SQLite). Nunca se sube a galerías públicas ni a la nube.
* **Extracción Semántica Local:** Al pulsar guardar, si la IA local está disponible, extrae `moodScore` (1–5), `energyLevel` (1–5), `stressLevel` (1–5), etiquetas temáticas (`tagsJson`) y un resumen empático en una línea. Si está apagada, se despliegan 3 deslizadores manuales en un diálogo de 1 toque.

---

## 3. Motor de Correlaciones Estadísticas Cruzadas (`CrossAnalyticsEngine`)

A partir de 14 días de datos en SQLite, el motor ejecuta análisis de correlación de Pearson y diferencias de medias para generar tarjetas de hallazgos basadas en evidencia:

1. **Sueño vs. Pérdida de Grasa / Apetito:**
   * Cruza `sleepDurationMinutes` de `daily_summaries` con la variación de peso y el total de calorías consumidas el día posterior.
   * *Ejemplo de tarjeta:* "Los días posteriores a dormir menos de 6 horas, tu ingesta calórica tiende a ser un 18% mayor."
2. **Nivel de Estrés vs. Ingesta Calórica:**
   * Cruza el `stressLevel` del diario con los carbohidratos y calorías de `food_logs`.
   * *Ejemplo de tarjeta:* "Detectamos una correlación moderada entre días con estrés nivel 4-5 y un mayor consumo de carbohidratos simples."
3. **Cumplimiento de Ayuno vs. Peso Tendencia (EMA):**
   * Compara la pendiente de `trendWeightKg` durante semanas con ayunos $\ge 16\text{ h}$ cumplidos frente a semanas sin ayuno.

> **Regla de Rigor:** El motor solo muestra una tarjeta si la serie temporal cuenta con al menos 10 pares de datos válidos y un coeficiente estadísticamente significativo, formulando el hallazgo siempre como una relación observada y no como una orden médica.

