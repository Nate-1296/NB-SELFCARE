# Historial de cambios

## 1.1.0 — 2026-10-28

Cuidado: todo lo que también es cuidarse y no cabía en Comida, Cuerpo ni Nibi. Y la app deja de suponer que tienes un NXTPAPER y una Mi Scale 2.

### Nueva pestaña Cuidado
- **Medicamentos y suplementos**: varias horas al día, días de la semana, toma "tomada" u "omitida" con Deshacer, reserva con aviso cuando queda para una semana, avisos con botón **Hecho** que funciona con la app cerrada. "Puede bajar el azúcar" activa el aviso antes de ayunar. Los medicamentos no dan monedas.
- **Mis hábitos**: los tuyos (hilo dental, protector solar…), con icono y días; un toque para marcarlos.
- **Suelo pélvico**: programa en 5 niveles (lentas, rápidas y relajación final), "Solo relajar" para quien nota tensión y guía por vibración para hacerlo con los ojos cerrados. Para cualquier sexo.
- **Pausas activas y descanso visual**: cinco rutinas de 1 a 3 minutos con una figura que muestra cada movimiento; regla 20-20-20.
- **Signos vitales**: tensión, glucosa, oxígeno y temperatura, solo si tienes el aparato; a mano o desde Health Connect, con lectura orientativa y sin diagnósticos.
- **Síntomas**: un toque e intensidad; con ciclo, cólicos y similares; desde los 40, síntomas de perimenopausia. Entran en las correlaciones y en el informe.
- **Chequeos preventivos** según edad y sexo (odontología, tensión, citología, mamografía, próstata, colon, vacunas…), con intervalos editables y chequeos propios.
- **Alcohol y tabaco** (apagado por defecto): un toque por bebida o cigarrillo, semana en bebidas estándar y comparación en positivo. Las bebidas suman sus calorías en Comida.
- Cada apartado tiene su **Saber más** con fuentes, y todos se pueden ocultar.

### Tus equipos
- La bienvenida y Ajustes preguntan si tienes pantalla de papel, báscula Mi Scale 2 y aparatos de signos vitales. Lo que no tienes no aparece: sin papel no hay temas de papel; sin báscula, Cuerpo muestra "Tu peso", el IMC, el metabolismo basal y la cinta métrica. Quien ya usaba la app lo conserva todo.

### También
- **Bienestar OMS-5** opcional en la revisión del domingo; si sale bajo, se muestran líneas de apoyo (192 opción 4, 106, 123) que abren el marcador sin llamar. También en Cuidado y Ajustes.
- **Sueño**: hora de despertar y regularidad del horario de las dos últimas semanas. "Tu hora de dormir" ajusta la hora límite de la cafeína y un nuevo aviso para desconectar.
- **Ciclo**: en fase lútea o menstrual, Cuerpo recuerda que retener agua es normal.
- Nuevas correlaciones: sueño ↔ síntomas y alcohol ↔ sueño.
- La respiración con Nibi se guarda y, si está conectado, va a Health Connect.
- Tarjeta **Cuidado de hoy** en Inicio. Avisos discretos y privados en la pantalla de bloqueo.
- El informe PDF incluye medicamentos, signos vitales y síntomas frecuentes.

### Probado en el teléfono
- Las horas se eligen siempre en formato de 24 h: con el teléfono en 12 h, el selector en modo texto rechazaba las horas de la tarde (afectaba también a los recordatorios).
- La vibración del suelo pélvico se nota aunque la vibración al tocar esté desactivada en el sistema.
- Los avisos con "Deshacer" se quitan solos a los pocos segundos y un aviso nuevo reemplaza al anterior en vez de quedarse uno escondido debajo de otro.
- Las bebidas aparecen en Comida en mililitros ("330 ml"), no en gramos.
- Los siete días de la semana caben en una fila; la figura de las pausas tiene cuello; un aviso pendiente ya no tapa los botones de una sesión guiada; etiquetas de la tensión más cortas.

### Técnico
- Esquema v7 (35 tablas) con migración paso a paso; suplementos pasan a tratamientos sin perder datos.
- ADR-14 a ADR-17; documentación nueva en `docs/12_CARE.md`.

## 1.0.0 — 2026-10-28

Primera versión completa, resultado de una auditoría de calidad (documentación frente a código real) y siete fases de trabajo. Probada a fondo en el TCL 50 Pro NXTPAPER.

### Datos y fiabilidad
- **Copias de seguridad completas**: la restauración cubría 16 de 25 tablas y fallaba con copias antiguas; ahora restaura todas las tablas, migra copias de versiones anteriores sobre un archivo temporal y rechaza archivos corruptos o ajenos.
- **Esquema v6** con migraciones paso a paso y pruebas de cada versión a todas las posteriores. Las fotos del diario se guardan dentro de la base de datos y viajan en la copia de seguridad.
- **Racha justa**: un escudo por cada día perdido; si no alcanzan, la racha vuelve a empezar sin perder los escudos.
- La cinta métrica ya no altera pesajes de otros días ni da monedas de pesaje.
- Reloj inyectable (`Clock`) y días de calendario seguros ante cambios de horario y años bisiestos.
- Health Connect solo sincronizaba una vez; un nombre de más de 60 caracteres impedía terminar la bienvenida; un ayuno podía empezar dos veces o en el futuro; la báscula se quedaba "buscando" si se apagaba el Bluetooth. Corregidos junto a otros 10 errores encontrados con pruebas de casos límite.

### Probado en el teléfono
- Escribir dos veces en el diario el mismo día (o repetir cualquier recompensa diaria) lanzaba un error interno de la base de datos.
- El cronómetro del ayuno no aparecía en una instalación nueva: el permiso de notificaciones nunca se pedía. Ahora se pide al empezar un ayuno o activar un recordatorio; la notificación dice "Meta hoy/mañana a las…".
- Sin permiso de cámara, el escáner mostraba un error en inglés; ahora explica qué pasa y lleva a Ajustes.
- El dictado se quedaba "escuchando" si no se decía nada.
- La báscula buscaba indefinidamente; ahora se detiene a los 90 s con un aviso.
- Hojas que se metían bajo la barra de estado, encabezados de tarjeta que reservaban media fila para una insignia, botones de altura desigual en el diario.
- Informe PDF en español claro, con la edad correcta y los días con registro.
- Catálogo sin conexión ampliado de 23 a unos 165 alimentos (carnes, lácteos, frutas, verduras, cereales, legumbres, bebidas, salsas y platos típicos).

### Arquitectura
- Capa de aplicación (`features/*/application/`) con los casos de uso: pesaje en cascada, comidas, agua, ayuno, diario, recompensas, metas diarias únicas para toda la app.
- Dominio puro y testeable (`RewardPolicy`, `StreakPolicy`, `WeighInAnalyzer`, `DietPhasePolicy`, `NibiMoodResolver`, `BreathingSession`…).
- Guardrails automáticos: sin nube ni telemetría, sin `DateTime.now()` fuera del reloj, la UI nunca toca DAOs, `core/` y `shared/` no dependen de `features/`.
- Pantallas monolíticas de 1.400–2.600 líneas divididas por responsabilidad; todos los textos en el ARB.

### Integraciones Android
- Health Connect con el SDK oficial (pasos, sueño con fases, FC en reposo; peso, grasa e hidratación).
- Cronómetro del ayuno en la pantalla de bloqueo (sin servicio en primer plano), Live Update en Android 16.
- Recordatorios con `AlarmManager` que sobreviven al reinicio; pausas activas.
- Dictado solo en el dispositivo; permisos pedidos en contexto (cámara, micrófono, notificaciones).
- Release con R8 y firma propia.

### Diseño
- Sistema de diseño propio: tipografía para la jerarquía, una acción principal por bloque, sin cajas dentro de cajas, tokens de espacio, radio y movimiento.
- 24 temas (Papel sepia y Salvia y Lino nuevos) con contraste AA verificado; Modo Papel sin animaciones ni estelas.
- Microinteracciones (pulsación, cifras que cuentan, anillos y barras animados, entrada escalonada) y rendimiento (repintado aislado, sin desenfoques costosos).
- Formato de números en español en toda la app ("82,5 kg", "2.500 ml").

### Nibi 2.0
- Dragón vectorial animado (sin imágenes) que refleja tus hábitos reales, con reacciones al toque, manías propias y versión fija en papel.
- Santuario con respiración guiada (caja, triángulo, 4-7-8, coherencia).
- 9 sombreros, 5 accesorios, 7 colores y 9 escenarios con ambiente animado; tienda y armario rediseñados.

### Retirado
- La promesa de "IA local": el texto de comidas y el diario usan analizadores deterministas (ADR-03).
- Los sprites PNG de Nibi.

## 0.1.0 — 2026-10-23

Primera implementación de las seis fases del plan original: persistencia, báscula BLE y fórmulas, nutrición con Open Food Facts, mascota y monedas, ayuno y diario, copias de seguridad.
