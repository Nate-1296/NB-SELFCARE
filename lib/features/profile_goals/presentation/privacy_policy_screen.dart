import 'package:flutter/material.dart';

import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/widgets/health_card.dart';

/// Política de privacidad (exigida por Health Connect al conceder permisos).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const List<({String title, String body})> _sections = <({String title, String body})>[
    (
      title: 'Todo se queda en tu teléfono',
      body: 'NB Selfcare no tiene cuentas, servidores ni analítica. Tus datos viven en un único '
          'archivo SQLite dentro de la app y solo salen si tú exportas un respaldo.',
    ),
    (
      title: 'Qué leemos de Health Connect',
      body: 'Pasos, sueño (con sus fases), frecuencia cardíaca en reposo, peso, grasa corporal e '
          'hidratación. Los usamos para tu resumen diario, el índice de recuperación, el '
          'multiplicador de monedas por buen descanso y las correlaciones de tu perfil.',
    ),
    (
      title: 'Qué escribimos en Health Connect',
      body: 'Los pesajes de tu báscula, el porcentaje de grasa medido por bioimpedancia y los vasos '
          'de agua que registras, para que otras apps de salud que tú elijas puedan verlos.',
    ),
    (
      title: 'Lectura en segundo plano',
      body: 'Solo si activas "Pausas activas": cada 15 minutos se revisan, en el dispositivo, tus '
          'pasos de la última hora para invitarte a moverte.',
    ),
    (
      title: 'Cámara y micrófono',
      body: 'El escáner de códigos de barras y la lectura de tablas nutricionales usan ML Kit de '
          'Google ejecutado en el propio teléfono: las imágenes y los códigos no salen de él. ML Kit sí '
          'envía a Google métricas técnicas anónimas de funcionamiento, sin ningún dato tuyo. El '
          'dictado de comidas solo se activa si Android ofrece reconocimiento de voz sin conexión.',
    ),
    (
      title: 'Única consulta a internet hecha por la app',
      body: 'Al buscar un código de barras o un alimento que no está en tu catálogo, se consulta la '
          'base pública de Open Food Facts. La consulta no incluye ningún dato tuyo y el resultado '
          'se guarda en tu teléfono.',
    ),
    (
      title: 'Tú decides',
      body: 'Puedes retirar cualquier permiso desde Health Connect o desde los ajustes de Android en '
          'cualquier momento. NB Selfcare seguirá funcionando con registro manual.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Privacidad')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final ({String title, String body}) section = _sections[index];
          return HealthCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  section.title,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  section.body,
                  style: TextStyle(fontFamily: ScFonts.ui, fontSize: 13, height: 1.4, color: c.text2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
