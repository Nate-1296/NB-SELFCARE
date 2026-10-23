# 06 · Entrenamiento RPE en 5 Segundos y Gasto NEAT (`docs/06_WORKOUT_AND_NEAT.md`)

> **Contexto Técnico:** Arquitectura de estimación calórica por ejercicio, separación de actividad pasiva (NEAT vía pasos de Health Connect) y registro intencional ultra-rápido por bloques de Esfuerzo Percibido (RPE).

---

## 1. El Problema de la Fricción en el Registro de Ejercicio (ADR-01)

Las aplicaciones tradicionales de fitness exigen registrar cada ejercicio, serie, repetición y kilogramo levantado. Esto introduce entre 15 y 30 minutos de fricción por sesión, causando altas tasas de abandono.

NB Selfcare adopta un **modelo desacoplado**:
1. **NEAT Pasivo (Non-Exercise Activity Thermogenesis):** Los pasos y el movimiento cotidiano se leen automáticamente en segundo plano desde **Health Connect API 36**.
2. **Entrenamiento Intencional:** Se captura en **$< 5\text{ segundos}$** mediante 3 selectores simples que calculan el gasto energético neto mediante el Equivalente Metabólico de la Tarea (**MET**).

---

## 2. La Interfaz de 3 Selectores

El modal `QuickRpeWorkoutSheet` presenta:

1. **Categoría de Actividad (`category`):**
   * `weights` — Pesas / Entrenamiento de Fuerza con sobrecarga.
   * `calisthenics` — Calistenia / Ejercicio Funcional / Peso Corporal.
   * `cardio` — Trote, Ciclismo, Natación, HIIT.
   * `sports` — Fútbol, Baloncesto, Tenis, Pádel, Artes Marciales.
2. **Duración en Minutos (`durationMinutes`):**
   * Selector rápido o deslizador de $10$ a $180\text{ minutos}$ (valores por defecto: $30$, $45$, $60$, $90$).
3. **Intensidad Percibida (`rpeIntensity`):**
   * `light` — RPE 1–4: Respiración tranquila, se puede mantener una conversación fluida.
   * `moderate` — RPE 5–7: Respiración acelerada, esfuerzo sostenido, hablar con pausas.
   * `intense` — RPE 8–10: Máximo esfuerzo, sudoración intensa, incapacidad para hablar.

---

## 3. Matriz Oficial de METs y Ecuación de Gasto Neto

Para no duplicar el gasto basal que ya está contabilizado en la Tasa Metabólica Basal (BMR) del usuario, se descuenta $1.0\text{ MET}$ (equivalente al reposo estático):

| Categoría (`category`)                 | `light` (MET) | `moderate` (MET) | `intense` (MET) |
| :------------------------------------- | :-----------: | :--------------: | :-------------: |
| `weights` (Fuerza / Musculación)       |      3.5      |       5.0        |       6.5       |
| `calisthenics` (Calistenia / Funcional)|      3.8      |       5.5        |       8.0       |
| `cardio` (Cardiovascular / Intervalos) |      5.0      |       7.5        |      10.5       |
| `sports` (Deportes de Contacto/Equipo) |      5.0      |       7.0        |       9.5       |

### Fórmula del Gasto Calórico Neto

$$\text{NetMET} = \text{appliedMet} - 1.0$$

$$\text{NetCaloriesBurned} = \text{round}\left(\text{NetMET} \times 3.5 \times \frac{W_{\text{actual}}}{200} \times \text{durationMinutes}\right)$$

Donde $W_{\text{actual}}$ es el **último peso real registrado por la báscula Xiaomi BLE** (o el peso del perfil como fallback).

---

## 4. Impacto en el Balance Energético Diario

El gasto neto calculado se inserta en `workout_blocks` y se refleja inmediatamente en el Dashboard:
$$\text{Calorías Restantes} = \text{Meta Adaptativa (TDEE)} + \text{Gasto Neto Entrenamientos} - \text{Calorías Consumidas}$$

Esto garantiza que el usuario consuma más energía solo en proporción al esfuerzo real realizado, sin sobrestimaciones infladas por relojes comerciales.
