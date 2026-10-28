# Historial de cambios

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
