import '../../shared/utils/number_formats.dart';
import '../database/app_database.dart';

/// Veredicto de seguridad metabólica para un protocolo de ayuno propuesto.
class FastingSafetyVerdict {
  const FastingSafetyVerdict._({
    required this.isSafe,
    this.warningTitle,
    this.warningBody,
    this.recommendedAlternativeHours,
  });

  factory FastingSafetyVerdict.safe() {
    return const FastingSafetyVerdict._(isSafe: true);
  }

  factory FastingSafetyVerdict.warning({
    required String title,
    required String body,
    int? recommendedAlternativeHours,
  }) {
    return FastingSafetyVerdict._(
      isSafe: false,
      warningTitle: title,
      warningBody: body,
      recommendedAlternativeHours: recommendedAlternativeHours,
    );
  }

  final bool isSafe;
  final String? warningTitle;
  final String? warningBody;
  final int? recommendedAlternativeHours;
}

/// Etapa de reintroducción de alimentos para romper el ayuno de forma segura.
class FastBreakStage {
  const FastBreakStage({
    required this.phaseNumber,
    required this.timing,
    required this.title,
    required this.description,
    required this.recommendedFoods,
    required this.foodsToAvoid,
  });

  final int phaseNumber;
  final String timing;
  final String title;
  final String description;
  final List<String> recommendedFoods;
  final List<String> foodsToAvoid;
}

/// Asesor clínico y preventivo de dosificación segura del ayuno intermitente.
class FastingDosageAdvisor {
  /// Duración máxima por defecto con historial de trastornos de la conducta alimentaria (docs/01 §5).
  static const int maxHoursWithEdHistory = 16;

  /// Avisos derivados de las respuestas de seguridad del onboarding. Tienen
  /// prioridad sobre la dosificación semanal porque dependen de la persona.
  static FastingSafetyVerdict evaluatePersonalSafety({
    required int proposedTargetHours,
    required bool hasEatingDisorderHistory,
    required bool takesHypoglycemicMedication,
  }) {
    if (hasEatingDisorderHistory && proposedTargetHours > maxHoursWithEdHistory) {
      return FastingSafetyVerdict.warning(
        title: 'Ayunos largos desactivados por defecto',
        body: 'Indicaste antecedentes de trastornos de la conducta alimentaria. Para cuidarte, '
            'NB Selfcare propone ventanas de hasta $maxHoursWithEdHistory h. Si tu equipo de '
            'salud te indicó otra pauta, puedes continuar.',
        recommendedAlternativeHours: maxHoursWithEdHistory,
      );
    }
    if (takesHypoglycemicMedication) {
      return FastingSafetyVerdict.warning(
        title: 'Antes de ayunar, consulta tu medicación',
        body: 'Los medicamentos que bajan la glucosa (insulina, sulfonilureas…) pueden requerir '
            'ajustes durante el ayuno. Confirma esta pauta con tu médico y lleva contigo una '
            'fuente rápida de azúcar.',
      );
    }
    return FastingSafetyVerdict.safe();
  }

  /// Evalúa si el protocolo propuesto es seguro respecto al historial de los últimos 7 días.
  static FastingSafetyVerdict evaluateProtocolSafety({
    required int proposedTargetHours,
    required List<FastingSession> recentSessions,
    required DateTime now,
  }) {
    // Protocolos suaves o moderados (hasta 18h) son fisiológicamente seguros a diario
    if (proposedTargetHours < 20) {
      return FastingSafetyVerdict.safe();
    }

    final DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Filtrar sesiones completadas en los últimos 7 días con duración real ≥ 20 horas
    final List<FastingSession> prolongedSessions = recentSessions.where((s) {
      if (s.actualEndedAt == null) return false;
      final bool within7Days = s.actualEndedAt!.isAfter(sevenDaysAgo);
      final double hours = s.actualEndedAt!.difference(s.startedAt).inMinutes / 60.0;
      return within7Days && hours >= 19.5;
    }).toList();

    // 1. Regla de Días Consecutivos: No encadenar dos ayunos de 20h+ seguidos
    if (recentSessions.isNotEmpty) {
      final FastingSession lastSession = recentSessions.first;
      if (lastSession.actualEndedAt != null) {
        final double lastHours =
            lastSession.actualEndedAt!.difference(lastSession.startedAt).inMinutes / 60.0;
        final int hoursSinceLastEnded =
            now.difference(lastSession.actualEndedAt!).inHours;

        if (lastHours >= 19.5 && hoursSinceLastEnded < 36) {
          return FastingSafetyVerdict.warning(
            title: 'Recuperación Metabólica Recomendada',
            body:
                'Completaste un ayuno prolongado (${NumberFormats.fixed(lastHours, 1)} h) hace menos de 36 horas. '
                'Encadenar ayunos agresivos (OMAD 23:1) en días consecutivos eleva el cortisol matutino, '
                'puede degradar masa muscular magra y ralentizar la tasa metabólica basal (TDEE). '
                'Para hoy te sugerimos una ventana más amplia como 16:8 o 14:10.',
            recommendedAlternativeHours: 16,
          );
        }
      }
    }

    // 2. Regla Semanal: Máximo 2 ayunos de 20h+ por semana
    if (prolongedSessions.length >= 2) {
      return FastingSafetyVerdict.warning(
        title: 'Límite Semanal de Ayuno Prolongado',
        body:
            'Ya has realizado ${prolongedSessions.length} ayunos prolongados (≥20h/OMAD) en los últimos 7 días. '
            'Los protocolos de una sola comida al día (23:1) deben dosificarse con moderación (máximo 1 o 2 veces por semana) '
            'para asegurar suficiente reabastecimiento de micronutrientes esenciales y síntesis proteica. '
            'Recomendamos un protocolo estándar 16:8.',
        recommendedAlternativeHours: 16,
      );
    }

    return FastingSafetyVerdict.safe();
  }

  /// Retorna las 3 etapas clínicas de realimentación cuando el ayuno supera 18 horas.
  static List<FastBreakStage> getRefeedingGuidance(double actualHoursFast) {
    if (actualHoursFast < 18.0) {
      return const <FastBreakStage>[
        FastBreakStage(
          phaseNumber: 1,
          timing: 'Inmediato',
          title: 'Apertura Suave',
          description:
              'Para ayunos moderados (<18h), comienza con agua y tu comida habitual equilibrando proteínas magras y fibra.',
          recommendedFoods: <String>[
            'Agua con electrolitos',
            'Comida estándar',
            'Proteína magra',
          ],
          foodsToAvoid: <String>[
            'Exceso de frituras o ultraprocesados',
          ],
        ),
      ];
    }

    return const <FastBreakStage>[
      FastBreakStage(
        phaseNumber: 1,
        timing: 'Minuto 0',
        title: 'Despertar Digestivo & Electrolitos',
        description:
            'Tu sistema digestivo ha estado en reposo profundo. Inicia con líquidos tibios y minerales para activar enzimas gástricas sin generar choque osmótico ni subidón de insulina.',
        recommendedFoods: <String>[
          'Caldo de huesos o caldo vegetal tibio',
          'Vaso de agua con una pizca de sal marina / magnesio',
          'Té de manzanilla o jengibre sin endulzar',
        ],
        foodsToAvoid: <String>[
          'Bebidas azucaradas o zumos de frutas (pico de glucosa)',
          'Café solo fuerte en estómago vacío',
          'Bebidas heladas',
        ],
      ),
      FastBreakStage(
        phaseNumber: 2,
        timing: '30 a 45 minutos después',
        title: 'Grasas Suaves & Proteínas Fáciles',
        description:
            'Aporta nutrientes de lenta absorción que mantengan estable la glucosa sérica y preparen el microbioma para alimentos más densos.',
        recommendedFoods: <String>[
          'Medio aguacate con sal y aceite de oliva',
          '1 o 2 huevos revueltos o tibios',
          'Yogurt griego natural o kéfir sin azúcar',
          'Puñado pequeño de almendras remojadas',
        ],
        foodsToAvoid: <String>[
          'Pan blanco, galletas o harinas refinadas',
          'Carnes rojas muy grasas o pesadas',
          'Legumbres con piel dura (pueden causar gases)',
        ],
      ),
      FastBreakStage(
        phaseNumber: 3,
        timing: '2 horas después',
        title: 'Comida Principal Completa',
        description:
            'Tu tracto gastrointestinal ya está plenamente operativo. Puedes disfrutar tu comida nutritiva completa con tus objetivos de macronutrientes del día.',
        recommendedFoods: <String>[
          'Pechuga de pollo, pescado o tofu con vegetales al vapor',
          'Arroz integral o batata asada',
          'Ensalada fresca con semillas de calabaza',
        ],
        foodsToAvoid: <String>[
          'Comilonas masivas sin masticar pausadamente',
          'Alimentos ultraprocesados densos en sodio y grasas trans',
        ],
      ),
    ];
  }
}
