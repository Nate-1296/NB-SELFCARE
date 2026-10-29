# 08 · Nibi y recompensas

> Nibi, el dragón que acompaña al usuario, y la economía de monedas que hace agradable la constancia sin castigar a nadie.

---

## 1. Principios

- **Nibi siempre está bien.** No muere, no enferma, no se pone triste por ti y no regaña. Lo comprueba un test (guardrail 6) que prohíbe ese vocabulario en `features/pet_gamification/`.
- **Refleja hábitos reales**, no un medidor que se vacía: su ánimo sale de tus datos de hoy.
- **Sin archivos binarios** (ADR-09): todo Nibi, sus objetos y sus escenarios se dibujan con `CustomPainter`; no hay nada que pueda faltar o corromperse.

## 2. Ánimo y actividades

`NibiMoodResolver` (reglas puras en `domain/nibi_activity.dart`) decide su actividad de base:

| Condición | Actividad |
| :-- | :-- |
| 23:00–06:00 | Duerme (ojos cerrados, "Zz"). |
| Ayuno en curso ≥ 12 h | Zen, con aura de cetosis. |
| Meta de agua y buen sueño | Celebra (confeti). |
| Agua o sueño, un entreno o racha de 7 días | Feliz. |
| Ninguna comida registrada después de las 11:00 | Curioso (nunca reproche). |
| En otro caso | Reposo. |

Además: comiendo, bebiendo, entrenando, pesándose (sube a su mini báscula en Cuerpo) y jugando con una pelota. Lo que registras en la app le llega al momento: un vaso de agua lo hace beber; una comida, comer.

## 3. Animación

- `NibiChoreography` convierte cada actividad en una postura (`NibiPose`) en función del tiempo: respiración, parpadeo irregular, mirada, cola y alas. Son funciones puras y deterministas (mismo instante, mismo fotograma), lo que permite probarlas.
- Al cambiar de actividad la postura se interpola durante 350 ms.
- **Reacciones al toque** (`NibiReaction`): en la cabeza, caricia o bocanada de humo con llamita; en la panza, cosquillas; en alas, cola o patas, una vuelta o un salto; pulsación larga, ronroneo con notas. El botón "Acariciar" las va alternando.
- **Manías**: cuando está tranquilo, cada 7–14 s bosteza, mira alrededor, estira las alas o resopla.
- Un `Ticker` actualiza un `ValueNotifier` y el pintor se repinta solo (sin reconstruir widgets); pintar un fotograma cuesta menos de 4 ms en el test de referencia. Los tickers se detienen cuando la pestaña no está visible.
- **Modo Papel y "Quitar animaciones"**: sin ticker; pose fija por actividad con paleta de tinta. Las reacciones se muestran como un dibujo fijo durante 1,5 s.

## 4. Santuario

La pestaña Nibi reúne en una tarjeta el escenario, las píldoras de monedas, escudos y racha, el bocadillo y los cuidados (acariciar, dar agua, merienda, jugar y respirar). Debajo: "Su día contigo" (agua, sueño y comidas de hoy), el armario y la tienda.

### Respiración guiada

`BreathingSession` (`domain/breathing.dart`) redondea la duración elegida (1, 3 o 5 min) a respiraciones completas y calcula, para cada instante, la fase, la cuenta atrás y el nivel de los pulmones (con suavizado al inhalar y exhalar).

| Ritmo | Fases (s) | Para qué |
| :-- | :-- | :-- |
| Caja | 4-4-4-4 | Calma y foco. |
| Triángulo | 4-4-4 | Para empezar. |
| Relajante | 4-7-8 | Antes de dormir. |
| Coherencia | 5-5 | Seis respiraciones por minuto. |

Durante la sesión el escenario se atenúa, un anillo con una marca por fase (como el del ayuno) se expande y se contrae, y Nibi respira al mismo ritmo (`NibiChoreography.guided`). Cada cambio de fase vibra suavemente. Al terminar, Nibi celebra y da monedas una vez al día. En papel el escenario se retira y todo avanza una vez por segundo.

## 5. Cosméticos

Catálogo único en `PetCatalog` (`domain/pet_catalog.dart`); los nombres están en el ARB (`petItem…`).

| Tipo | Artículos | Precio |
| :-- | :-- | :-- |
| Sombreros (9) | Fiesta, chef, lana, gorra, cinta deportiva, corona de flores, halo zen, corona, mago. | 25–70 |
| Accesorios (5) | Pajarita, bufanda, cascabel, gafas redondas, gafas de sol. | 25–45 |
| Colores (7) | Jade (gratis), océano, lila, coral, brasa, medianoche, dorado. En papel, cada color es un gris distinto. | 50–90 |
| Escenarios (9) | Habitación (gratis), jardín zen, playa, bosque de luciérnagas, amanecer andino, valle nevado, dojo estelar, cerezos, luna y estrellas. | 40–75 |
| Escudos | Escudo de un día, pack de 3. | 25 / 65 |

- La **tienda** solo muestra lo que está a la venta; lo comprado pasa al **armario** y se pone al instante.
- Sombrero, accesorio, color y escenario se guardan en `pet_status` (desde el esquema v5). Un id desconocido (por ejemplo, de una copia de seguridad de otra versión) se ignora.
- El aspecto se ve igual en el santuario, el avatar de Inicio y la báscula de Cuerpo (`nibiLookProvider`).

## 6. Monedas (`coin_ledger`)

Cada acción paga **una vez al día** (índice único por día y tipo):

| Acción | Monedas |
| :-- | :-: |
| Pesarse | 15 |
| Desayuno, almuerzo y cena (los snacks no) | 10 cada una |
| Cumplir la meta de agua | 15 |
| Terminar un ayuno de 14 h o más | 20 |
| Registrar un entrenamiento | 20 |
| Escribir en el diario | 10 |
| Sueño reparador | 15 |
| Alcanzar una meta intermedia | 25 |
| Revisión del domingo | 15 |
| Respirar con Nibi | 10 |
| Sesión de suelo pélvico | 10 |
| Pausa activa o descanso visual | 10 |
| Completar todos los hábitos propios del día | 10 |
| Registrar un chequeo preventivo | 20 |

Los medicamentos y suplementos **no** dan monedas (ADR-17): un tratamiento no es un juego y una toma olvidada nunca debe sentirse como un fallo.

- **Multiplicador de sueño:** si anoche se cumplió la meta de sueño (o REM + profundo ≥ 90 min), las monedas del día valen ×1,5 (redondeando hacia arriba).
- **Racha:** cuenta los días con al menos una recompensa. Cada día perdido consume un escudo; si no alcanzan, la racha vuelve a 1 y los escudos se conservan (`StreakPolicy`).
- El saldo nunca es negativo y una compra no se paga dos veces.
