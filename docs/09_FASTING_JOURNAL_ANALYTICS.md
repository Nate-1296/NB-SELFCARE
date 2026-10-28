# 09 · Ayuno, diario y analítica

> **Contexto Técnico:** Temporizador de ayuno intermitente con fases metabólicas y cronómetro nativo en pantalla de bloqueo, diario privado con fotos locales y motor estadístico de correlaciones cruzadas.

---

## 1. Motor de Ayuno Intermitente y Fases Metabólicas

NB Selfcare implementa un temporizador de alta eficiencia que no mantiene procesos activos en segundo plano:

* **Protocolos:** 14:10 (suave), 16:8 (el más popular), 18:6, 20:4 y personalizado (horas exactas). El ayuno puede empezar ahora o en una hora anterior ("Empecé antes"), y la hora de inicio se puede ajustar después.
* **Seguridad (`FastingDosageAdvisor`):** con antecedentes de trastornos alimentarios se proponen ayunos de hasta 16 h; con medicación que baja la glucosa, un aviso antes de empezar; tras un ayuno prolongado reciente, una sugerencia de pausa.
* **Romper el ayuno:** tras 16 h o más se ofrece una guía para la primera comida.

### Línea de Tiempo Fisiológica

La interfaz mapea la hora actual del ayuno con la transición bioquímica real:

| Intervalo | Fase Metabólica | Marcador Fisiológico |
| :-- | :-- | :-- |
| **$0\text{–}4\text{ h}$** | **Fase digestiva** | Digestión, absorción de glucosa y aminoácidos, insulina elevada. |
| **$4\text{–}12\text{ h}$** | **Usando glucógeno** | Caída de insulina a nivel basal; degradación de glucógeno hepático para mantener normoglucemia. |
| **$12\text{–}18\text{ h}$** | **Quema de grasa** | Agotamiento del glucógeno hepático; activación de lipasa sensible a hormonas y beta-oxidación de ácidos grasos. Se activa el aura en la mascota `Nibi`. |
| **$18\text{–}24\text{ h}$** | **Cetosis** | Producción hepática de cuerpos cetónicos ($\beta$-hidroxibutirato y acetoacetato). |
| **$> 24\text{ h}$** | **Autofagia** | Reciclaje lisosomal de orgánulos y proteínas dañadas. *Aviso de seguridad y recordatorio de electrolitos (Na, K, Mg)*. |

### Notificación Persistente con Cero Consumo de CPU

Para no agotar la batería, la notificación usa el cronómetro del propio sistema (`FastingNotifier`, en Kotlin):
```kotlin
NotificationCompat.Builder(context, NotificationChannels.FASTING)
    .setUsesChronometer(true)
    .setChronometerCountDown(false)
    .setWhen(sessionStartedAtTimestamp)
    .setOngoing(true)
```
Android actualiza los segundos sin que la app esté en memoria. En **Android 16** se promueve a *Live Update* (chip en la barra de estado). El texto ("Ayuno 16:8 · Quema de grasa", "Meta mañana a las 15:28") se actualiza con alarmas inexactas en cada cambio de fase y a medianoche; los nombres de las fases coinciden con los de la app (lo verifica `native_contract_test`).

---

## 2. Diario Privado y Metadatos Locales

* **Entrada de Texto Libre:** Para registrar reflexiones, sensaciones de energía, comidas fuera de casa o eventos de vida.
* **Ánimo, energía y estrés** (1–5) con selectores de un toque, y frases guía (gratitud, sensación corporal, pequeño logro, soltar tensión) para empezar a escribir.
* **Foto de progreso:** se copia a la carpeta privada de la app; nunca va a la galería ni a la nube.
* **Etiquetas y resumen:** `TextAssistant.analyzeJournal` extrae temas por diccionario y una línea de resumen, sin modelos de lenguaje. "Sugerir estado" propone ánimo, energía y estrés a partir del texto.
* **Cafeína y sueño:** cada toma con su dosis; un modelo farmacocinético (vida media de 5,5 h) estima cuánta queda al acostarse y sugiere la hora límite del último café.
* **Digestión:** escala de Bristol y molestias, para cruzarlas con lo comido.

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

