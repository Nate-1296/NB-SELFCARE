# 10 · Seguridad, Privacidad Offline y Estrategia de Pruebas (`docs/10_SECURITY_AND_TESTING.md`)

> **Contexto Técnico:** Protocolos de auditoría de cero fugas de red, pruebas unitarias para algoritmos fisiológicos y verificación de integridad de la base de datos local Drift.

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

## 2. Batería de Pruebas Unitarias Obligatorias (`test/`)

Todo desarrollo debe mantener un estándar de **100% de éxito** en los siguientes módulos críticos:

### A. Fórmulas Biométricas (`test/biometrics_test.dart`)
* Verificación de la ecuación de **Katch-McArdle** contra valores de referencia clínicos.
* Verificación de la ecuación **US Navy** para hombres y mujeres con casos límite de circunferencia de cuello y cintura.
* Verificación del cálculo de gasto neto por **METs** con descuento de $1.0\text{ MET}$ de reposo y peso dinámico.
* Prueba de suavizado exponencial (**EMA**) con $\alpha = 0.1$:
  * Comprobar convergencia suave ante picos atípicos de un solo día.
* Prueba del **Detector de Falsa Subida**:
  * Simulación de subida de $0.6\text{ kg}$ tras día de alto sodio ($>2500\text{ mg}$) o recarga de glucógeno: debe disparar `isWaterRetentionSpike = true`.
* Prueba del **TDEE Adaptativo (14 días)**:
  * Validación del cálculo con déficit y superávit calórico controlado.
  * Verificación de la regla de acotamiento (clamp semanal máximo de $\pm 150\text{ kcal}$).

### B. Parser de 13 Bytes de la Báscula Xiaomi (`test/scale_parser_test.dart`)
* Decodificación de tramas de prueba hex (`0x02` con impedancia, `0x20` estabilizada).
* Verificación de conversión de unidades: modo kg ($raw / 200$), modo lbs ($raw / 100$).
* Validación del filtro de descarte para paquetes históricos (`bytes[1] & 0x80`).

### C. Base de Datos Drift y FTS5 (`test/database_test.dart`)
* Inicialización en memoria (`NativeDatabase.memory()`).
* Verificación de búsqueda `FTS5` sin diacríticos (ej. buscar "platano" debe devolver "Plátano maduro").
* Verificación de restricciones de unicidad e idempotencia en `coin_ledger` para llaves compuestas `(date_key, action_type)`.
* Verificación del comando nativo `VACUUM INTO` para exportación atómica de base de datos.

### D. Gamificación y Escudos de Racha (`test/gamification_test.dart`)
* Aplicación del multiplicador $1.5\times$ en monedas cuando el sueño alcanza la meta.
* Consumo automático de `StreakShield` ante día sin registros, preservando `currentStreakDays`.

