# 01 · Producto

> Qué hace NB Selfcare y por qué. El cómo está en los documentos 02–10; las decisiones, en [`11_DECISIONS.md`](11_DECISIONS.md).

## 1. Visión

Una sola app, solo para ti, que reúne lo que normalmente reparten varias apps de pago: registro de comida y micronutrientes, báscula inteligente, gasto calórico adaptativo, ayuno, sueño y descanso, diario y una mascota que hace agradable la constancia.

- **Usuario:** una persona, el dueño del teléfono. Sin cuentas ni funciones sociales.
- **Dispositivo de referencia:** TCL 50 Pro NXTPAPER (Android 16) + Xiaomi Mi Body Composition Scale 2 (`XMTZC05HM`).
- **Idioma:** español; todos los textos están en `lib/core/l10n/arb/app_es.arb`.

## 2. Principios

| # | Principio | Cómo se cumple |
| :-: | :-- | :-- |
| 1 | **Sin nube ni telemetría** | Todo vive en `nb_selfcare.sqlite`. La única red es Open Food Facts al escanear un código desconocido; el producto se guarda al instante. `allowBackup="false"`. |
| 2 | **Portabilidad** | Copia de seguridad = un archivo `.sqlite` (fechas en texto ISO-8601), restaurable con validación. |
| 3 | **Menos de 15 s** | Ningún registro necesita formularios largos; todo ofrece *Deshacer*. |
| 4 | **Cascada reactiva** | Un pesaje o un cambio de día recalcula tendencia, metas, recompensas y el ánimo de Nibi sin botón de "actualizar". |
| 5 | **Color y papel** | 24 temas en color (incluido Material You) y Modo Papel para E-Ink: sin sombras ni animaciones, bordes de 1,5 px, sin estelas. |
| 6 | **Positividad** | Nada de castigos ni culpa. Nibi nunca enferma; una racha perdida se reinicia sin reproches. |
| 7 | **Degradación elegante** | Sin Health Connect, sin báscula, sin red o sin permisos, la app sigue funcionando con registro manual. |

## 3. Pantallas

### Inicio (`/hoy`)

- **Cabecera** con saludo según la hora y franja de hábitos del día.
- **Disposición del día** (0–100): sueño, pulso en reposo y carga reciente, con cafeína y su hora límite.
- **Tarjetas** que se ordenan, se redimensionan (2×2, 4×2, 4×4) y se ocultan: Nibi, objetivos de comida, agua, peso, pasos, sueño, entrenamiento, ayuno y diario.
- **Diario rápido** con ánimo, energía, estrés, frases guía y foto.
- **Revisión del domingo**: resumen semanal y registro de cómo te sientes.

### Comida (`/comer`)

- Semana navegable y buscador (catálogo USDA en español + lo escaneado + lo creado; búsqueda FTS5 sin tildes).
- **Escáner** EAN/UPC con caché local y Open Food Facts; si no hay red o no existe, alta guiada o **lectura de la etiqueta** con OCR.
- **Escribir comida**: texto o dictado en el dispositivo; un analizador determinista separa alimentos y gramos y siempre muestra una revisión editable.
- **Combos** con escalador 0,25×–3×, **recetas** por lotes con raciones, **crear alimento**, **menú sugerido** según las macros restantes.
- Balance energético (meta + ejercicio neto), macros, electrolitos (sodio, potasio, magnesio) y fibra, procesado NOVA, comidas del día con "repetir ayer" y agua con vasos personalizados.

### Cuerpo (`/cuerpo`)

- Peso actual, tendencia y distancia a la meta; **metas intermedias** de 1,5 kg.
- **Pesaje con la báscula** (sin la app del fabricante): peso en vivo, 13 métricas y filtro de invitado ("¿eres tú?"). Pesaje manual y **cinta métrica** (US Navy, fusión 60 % BIA / 40 % cinta).
- **Evolución**: gráfica por medida (peso, grasa, músculo, agua, visceral, puntuación, grasa validada) y período, con historial.
- Composición corporal detallada, pasos (NEAT) y **entrenamientos en 5 s** (tipo + minutos + esfuerzo → kcal netas con tu último peso).
- Ciclo menstrual (si se activa en el perfil).

### Nibi (`/nibi`)

- Santuario con monedas, escudos y racha; Nibi refleja tus hábitos reales (duerme de noche, celebra metas, entra en zen con ayunos largos).
- Cuidados: acariciar, dar agua, merienda, jugar y **respirar** (sesión guiada de 1, 3 o 5 minutos).
- Armario con lo que ya tiene y **tienda** de escudos y cosméticos (sombreros, accesorios, colores y escenarios). Detalle en [`08`](08_NIBI_AND_REWARDS.md).

### Perfil (`/perfil`)

- Datos personales (la edad se calcula al vuelo), metas y **gasto diario adaptativo** (recalibrado cada 14 días), fase de dieta, ciclado de calorías, suplementos, correlaciones entre hábitos e **informe PDF**.
- **Protocolo semanal** (`/protocolo`): días de ayuno y entreno, estilo de alimentación.
- **Ajustes** (`/ajustes`): temas, recordatorios, pausas activas, báscula, Health Connect, permisos, copias de seguridad y política de privacidad.

### Ayuno (`/ayuno`)

Protocolos 14:10, 16:8, 18:6, 20:4 y personalizado; inicio ahora o antes; anillo con fases (digestiva, glucógeno, quema de grasa, cetosis, autofagia); aviso de seguridad según el perfil; cronómetro en la pantalla de bloqueo; guía para romper ayunos largos; historial. Una barra persistente muestra el ayuno en curso en todas las pestañas.

## 4. Presupuesto de fricción

| Flujo | Toques | Tiempo |
| :-- | :-: | :-: |
| Vaso de agua | 1 | < 2 s |
| Repetir comida de ayer | 1 | < 3 s |
| Combo habitual | 2–3 | < 6 s |
| Entrenamiento | 3–4 | < 5 s |
| Producto ya escaneado | 2–3 | < 8 s |
| Pesaje con la báscula | 1 + subirse | < 15 s |
| Entrada corta de diario | 2 + texto | < 15 s |

## 5. Salud y seguridad

- **No es un dispositivo médico.** La bioimpedancia y las fases del ayuno son estimaciones.
- La bienvenida pregunta por marcapasos/implantes/embarazo (la báscula mide solo peso), antecedentes de trastornos alimentarios (ritmo suave, ayunos de hasta 16 h, déficit máximo menor) y medicación que baja la glucosa (aviso antes de cada ayuno).
- Nunca se proponen calorías por debajo del metabolismo basal; el déficit diario tiene un tope.

## 6. Alcance

| Sí | No |
| :-- | :-- |
| SQLite local y copias exportables. | Cuentas, nube, telemetría o copias automáticas en Google. |
| Mi Scale 2 directa + contrato `BodyScaleDriver` para otras básculas. | Drivers para decenas de marcas (entran por Health Connect). |
| Health Connect: lee pasos, sueño y FC en reposo; escribe peso, grasa e hidratación. | SDKs privados o deprecados (Google Fit, Samsung Health, Zepp). |
| Entrenamientos por bloques (tipo + minutos + esfuerzo). | Registro serie por serie. |
| Gamificación positiva. | Mecánicas de castigo o sociales. |
| Android, en español. | iOS, web y escritorio. |
