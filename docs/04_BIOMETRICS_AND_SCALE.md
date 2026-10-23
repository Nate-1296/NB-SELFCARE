# 04 · Biometría, Protocolo de Báscula BLE y Algoritmos Fisiológicos (`docs/04_BIOMETRICS_AND_SCALE.md`)

> **Contexto Técnico:** Especificación del protocolo BLE de la **Xiaomi Mi Body Composition Scale 2 (`XMTZC05HM`)**, derivación matemática de las **13 métricas**, Peso Tendencia (EMA), Detector de Retención Hídrica y calibrador de **TDEE Adaptativo (14 días)**.

---

## 1. Protocolo GATT BLE: Xiaomi Mi Body Composition Scale 2

La báscula utiliza el estándar Bluetooth GATT Body Composition con extensiones del fabricante Xiaomi.

* **Service UUID:** `0000181b-0000-1000-8000-00805f9b34fb` (`0x181B`)
* **Characteristic UUID:** `00002a9c-0000-1000-8000-00805f9b34fb` (`0x2A9C`)
* **Service Data en Advertisements:** La báscula emite la misma trama de 13 bytes en los paquetes publicitarios de escaneo pasivo. Esto permite leer el peso en tiempo real **sin necesidad de emparejamiento invasivo ni abrir la app oficial Zepp Life**.

### Estructura de la Trama de 13 Bytes (`Uint8List`)

| Byte | Nombre | Descripción y Operaciones a Nivel de Bits |
| :-- | :-- | :-- |
| `0` | Control Byte 0 | `(byte & 0x01) != 0` → Libras (lbs). `(byte & 0x10) != 0` → Catty (jin). Si ambos `0` → **Kilogramos (kg)**. |
| `1` | Control Byte 1 | **Flags Críticos:**<br>• Bit 1 (`0x02`): `hasImpedance` (1 si completó bioimpedancia).<br>• Bit 5 (`0x20`): `isStabilized` (1 si el peso ya no fluctúa).<br>• Bit 7 (`0x80`): `isHistoricalLoad` (1 si es paquete guardado en memoria offline; ignorar en pesaje en vivo). |
| `2..3`| Año | Entero sin signo 16-bit Little-Endian: `(bytes[3] << 8) \| bytes[2]`. |
| `4` | Mes | Entero 8-bit (1–12). |
| `5` | Día | Entero 8-bit (1–31). |
| `6` | Hora | Entero 8-bit (0–23). |
| `7` | Minuto | Entero 8-bit (0–59). |
| `8` | Segundo | Entero 8-bit (0–59). |
| `9..10`| Impedancia $\Omega$ | Entero 16-bit Little-Endian: `(bytes[10] << 8) \| bytes[9]`. Contacto válido pies descalzos: $100 \le \Omega \le 3000$. |
| `11..12`| Peso Bruto | Entero 16-bit Little-Endian: `(bytes[12] << 8) \| bytes[11]`. En modo kg: `weightKg = raw / 200.0`. |

### Manejo de Seguridad y Filtro de Invitados

1. **Contraindicación Médica:** Si en el perfil el usuario marca uso de marcapasos, implantes cardíacos o embarazo, la app desactiva la lectura de impedancia y registra únicamente el peso bruto.
2. **Filtro de Invitados:** Si el peso estabilizado difiere más de un $8\%$ respecto al último `trendWeightKg` (EMA), la app muestra un diálogo: *"¿Eres tú o alguien más usó la báscula?"* para evitar contaminar la serie histórica.

---

## 2. Derivación Matemática de las 13 Métricas Biométricas

Dados: Peso $W$ ($\text{kg}$), Estatura $H$ ($\text{cm}$), Edad $A$ ($\text{años}$), Impedancia $Z$ ($\Omega$) y Sexo Biológico (`isMale` $\text{bool}$):

### 1. Índice de Masa Corporal (IMC)
$$\text{BMI} = \frac{W}{(H / 100)^2}$$

### 2. Coeficiente de Masa Libre de Grasa (LBM)
$$\text{LBM}_{\text{base}} = \left(\frac{H \times 9.058}{100}\right) \times \left(\frac{H}{100}\right) + (W \times 0.32) + 12.226 - (Z \times 0.0068) - (A \times 0.0542)$$

### 3. Porcentaje de Grasa Corporal ($\text{BF}\%$)
Se aplican los coeficientes de ajuste empíricos de la báscula Xiaomi:
* Si `isMale == true`: $\text{adjust} = 0.8$, $\text{coeff} = (W < 61.0 \, ? \, 0.98 : 1.0)$.
* Si `isMale == false`: $\text{adjust} = (A \le 49 \, ? \, 9.25 : 7.25)$.
  * Si $W > 60.0$: $\text{coeff} = 0.96 \times (H > 160.0 \, ? \, 1.03 : 1.0)$.
  * Si $W < 50.0$: $\text{coeff} = 1.02 \times (H > 160.0 \, ? \, 1.03 : 1.0)$.
  * En otro caso: $\text{coeff} = 1.0$.

$$\text{BF}\% = \text{clamp}\left(\left(1.0 - \frac{(\text{LBM}_{\text{base}} - \text{adjust}) \times \text{coeff}}{W}\right) \times 100, \, 5.0, \, 75.0\right)$$

### 4. Masa Ósea ($\text{BoneMassKg}$)
$$\text{Base} = \text{isMale} \, ? \, 0.18016894 : 0.245691014$$
$$\text{BoneRaw} = -1.0 \times \left(\text{Base} - (\text{LBM}_{\text{base}} \times 0.05158)\right)$$
$$\text{BoneMassKg} = \text{clamp}(\text{BoneRaw} > 2.2 \, ? \, \text{BoneRaw} + 0.1 : \text{BoneRaw} - 0.1, \, 1.0, \, 5.2)$$

### 5. Masa Muscular ($\text{MuscleMassKg}$)
$$\text{MuscleMassKg} = W - \left(W \times \frac{\text{BF}\%}{100}\right) - \text{BoneMassKg}$$

### 6. Porcentaje de Agua Corporal ($\text{Water}\%$)
$$\text{WaterRaw} = (100.0 - \text{BF}\%) \times 0.70$$
$$\text{Water}\% = \text{clamp}(\text{WaterRaw} < 50.0 \, ? \, \text{WaterRaw} \times 1.02 : \text{WaterRaw} \times 0.98, \, 35.0, \, 75.0)$$

### 7. Porcentaje de Proteína Corporal ($\text{Protein}\%$)
$$\text{Protein}\% = \text{clamp}\left(\left(\frac{\text{MuscleMassKg}}{W}\right) \times 100 - (\text{Water}\% \times 0.52), \, 10.0, \, 26.0\right)$$

### 8. Grasa Visceral (Índice 1–30)
Ecuación bilineal según altura y peso:
* Para hombres:
  * Si $H < W \times 1.6$: $\text{subcalc} = -1.0 \times (H \times 0.4 - H^2 \times 0.0826)$, $\text{visceral} = \frac{W \times 305.0}{\text{subcalc} + 48.0} - 2.9 + (A \times 0.15)$.
  * En otro caso: $\text{subcalc} = 0.765 + H \times (-0.0015)$, $\text{visceral} = -1.0 \times (H \times 0.143 - W \times \text{subcalc}) + (A \times 0.15) - 5.0$.
* Para mujeres: ecuación simétrica calibrada. Clamped en $[1, 30]$.

### 9. Tasa Metabólica Basal (BMR Katch-McArdle)
$$\text{LBM}_{\text{real}} = W \times \left(1.0 - \frac{\text{BF}\%}{100}\right)$$
$$\text{BMR} = \text{round}(370 + 21.6 \times \text{LBM}_{\text{real}})$$

### 10. Edad Metabólica
Compara el BMR frente a la tabla estandarizada de Harris-Benedict por edad, acotada al rango $[A - 10, \, A + 15]$.

### 11. Masa Libre de Grasa (LBM kg)
$$\text{LeanBodyMassKg} = \text{roundTo1Decimal}\left(W - \left(W \times \frac{\text{BF}\%}{100}\right)\right)$$

### 12. Puntaje Corporal (Body Score 10–100)
Comienza en 100 y deduce penalizaciones según desviaciones de rangos óptimos:
$$\text{BodyScore} = \text{clamp}(100 - \Delta\text{BMI} - \Delta\text{Fat} - \Delta\text{Muscle} - \Delta\text{Water} - \Delta\text{Visceral} - \Delta\text{Bone} - \Delta\text{BMR} - \Delta\text{Protein}, \, 10, \, 100)$$

### 13. Somatotipo (9 Fenotipos Corporales)
Matriz $3 \times 3$ cruzando nivel de grasa (Bajo, Normal, Alto) y masa muscular (Bajo, Normal, Alto):
* `obese`, `overweight`, `thick_set`, `lack_exercise`, `balanced`, `balanced_muscular`, `skinny`, `balanced_skinny`, `skinny_muscular`.

---

## 3. Validación Antropométrica Quincenal (Ecuación US Navy)

Para compensar variaciones hídricas de la bioimpedancia:
* **Hombres:**
  $$\text{BF}_{\text{Navy}} = \frac{495}{1.0324 - 0.19077 \log_{10}(\text{cintura} - \text{cuello}) + 0.15456 \log_{10}(H)} - 450$$
* **Mujeres:**
  $$\text{BF}_{\text{Navy}} = \frac{495}{1.29579 - 0.35004 \log_{10}(\text{cintura} + \text{cadera} - \text{cuello}) + 0.22100 \log_{10}(H)} - 450$$
* **Fusión Ponderada:**
  $$\text{ValidatedBF}\% = (0.60 \times \text{BF}_{\text{BIA}}) + (0.40 \times \text{BF}_{\text{Navy}})$$

---

## 4. Peso Tendencia (EMA) y Detector de Falsa Subida

### Media Móvil Exponencial ($\alpha = 0.1$)
$$\text{EMA}_t = \text{EMA}_{t-1} + 0.1 \times (W_t - \text{EMA}_{t-1})$$

### Detector de Retención Hídrica / Glucógeno
Si $W_t - W_{t-1} \ge 0.40\text{ kg}$, se evalúan las condiciones:
1. `Sodio Alto`: $\text{sodio}_{t-1} > 2500\text{ mg}$.
2. `Supercompensación de Glucógeno`: $\text{carbohidratos}_{t-1} > 1.30 \times \overline{\text{carbos}}_{7\text{d}}$ ($1\text{ g}$ de glucógeno almacena $\approx 3.7\text{ g}$ de agua).
3. `Salto de Agua BIA`: $\text{Water}\%_t - \text{Water}\%_{t-1} \ge 0.4\%$.

Si alguna es verdadera, se marca `isWaterRetentionSpike = true` y se despliega la tarjeta informativa tranquilizadora.

---

## 5. Motor de TDEE Adaptativo (Ventana Móvil de 14 Días)

Cada 14 días (con $\ge 10$ días de registro nutricional y $\ge 6$ pesajes):
$$\Delta\text{EMA}_{14\text{d}} = \text{EMA}_{\text{hoy}} - \text{EMA}_{\text{hace 14 días}}$$
$$\text{TDEE}_{\text{Real}} = \text{round}\left(\overline{\text{KcalConsumidas}}_{14\text{d}} - \frac{\Delta\text{EMA}_{14\text{d}} \times 7700}{14}\right)$$

* **Filtro de Seguridad:** La calibración no puede variar más de $\pm 150\text{ kcal}$ por semana respecto al TDEE previo, y nunca se sitúa por debajo del BMR del usuario.

