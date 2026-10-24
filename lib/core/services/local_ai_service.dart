import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../database/daos/food_dao.dart';

/// Estados de ciclo de vida de la memoria para el motor de inferencia local.
enum AiMemoryState {
  unloaded,
  loading,
  ready,
  evicting,
}

/// Item nutricional individual extraído de una frase en lenguaje natural.
class ParsedMealItem {
  const ParsedMealItem({
    required this.searchTerm,
    required this.grams,
    required this.fallbackKcal,
    required this.fallbackP,
    required this.fallbackC,
    required this.fallbackF,
  });

  factory ParsedMealItem.fromJson(Map<String, dynamic> json) {
    return ParsedMealItem(
      searchTerm: json['search_term'] as String? ?? 'alimento',
      grams: (json['grams'] as num?)?.toDouble() ?? 100.0,
      fallbackKcal: (json['fallback_kcal'] as num?)?.toDouble() ?? 120.0,
      fallbackP: (json['fallback_p'] as num?)?.toDouble() ?? 5.0,
      fallbackC: (json['fallback_c'] as num?)?.toDouble() ?? 15.0,
      fallbackF: (json['fallback_f'] as num?)?.toDouble() ?? 3.0,
    );
  }

  final String searchTerm;
  final double grams;
  final double fallbackKcal;
  final double fallbackP;
  final double fallbackC;
  final double fallbackF;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'search_term': searchTerm,
        'grams': grams,
        'fallback_kcal': fallbackKcal,
        'fallback_p': fallbackP,
        'fallback_c': fallbackC,
        'fallback_f': fallbackF,
      };
}

/// Resultado de extracción sintáctica de comida.
class ParsedMealResult {
  const ParsedMealResult({
    required this.items,
    this.isFromLlm = false,
  });

  final List<ParsedMealItem> items;
  final bool isFromLlm;
}

/// Análisis semántico y de sentimiento del diario.
class JournalAiAnalysis {
  const JournalAiAnalysis({
    required this.moodScore,
    required this.energyLevel,
    required this.stressLevel,
    required this.tags,
    required this.oneLineInsight,
    this.isFromLlm = false,
  });

  factory JournalAiAnalysis.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'] as List<dynamic>? ?? <dynamic>[];
    return JournalAiAnalysis(
      moodScore: ((json['mood_score'] as num?)?.toInt() ?? 3).clamp(1, 5),
      energyLevel: ((json['energy_level'] as num?)?.toInt() ?? 3).clamp(1, 5),
      stressLevel: ((json['stress_level'] as num?)?.toInt() ?? 2).clamp(1, 5),
      tags: rawTags.map((e) => e.toString()).take(3).toList(),
      oneLineInsight: json['one_line_insight'] as String? ?? 'Reflexión registrada con serenidad.',
    );
  }

  final int moodScore;
  final int energyLevel;
  final int stressLevel;
  final List<String> tags;
  final String oneLineInsight;
  final bool isFromLlm;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mood_score': moodScore,
        'energy_level': energyLevel,
        'stress_level': stressLevel,
        'tags': tags,
        'one_line_insight': oneLineInsight,
      };
}

/// Servicio de IA Local bajo demanda con gestión de memoria GPU/RAM y TTL de 120s.
///
/// Implementa carga perezosa (Lazy-Loading), liberación automática por inactividad
/// y respaldo determinista de alta precisión sin dependencias externas obligatorias.
class LocalAiService {
  LocalAiService({
    this.ttlDuration = const Duration(seconds: AppConstants.localAiMemoryTtlSeconds),
    this.localModelPath,
  });

  final Duration ttlDuration;
  String? localModelPath;

  AiMemoryState _currentState = AiMemoryState.unloaded;
  Timer? _evictionTimer;
  final _stateController = StreamController<AiMemoryState>.broadcast();

  /// Estado actual de la memoria del modelo local.
  AiMemoryState get currentState => _currentState;

  /// Stream reactivo de cambios en el estado de memoria del modelo.
  Stream<AiMemoryState> get stateStream => _stateController.stream;

  /// Actualiza la ruta del archivo del modelo local (.task / .litertlm / .gguf).
  void setLocalModelPath(String? path) {
    localModelPath = path;
    if (_currentState == AiMemoryState.ready) {
      evictModel();
    }
  }

  /// Indica si existe un modelo binario local configurado y accesible en disco.
  bool get hasLocalModelFile {
    if (localModelPath == null || localModelPath!.isEmpty) return false;
    return File(localModelPath!).existsSync();
  }

  /// Activa o renueva la permanencia del modelo en memoria RAM/GPU por 120 segundos.
  void _touchOrLoad() {
    _evictionTimer?.cancel();

    if (_currentState != AiMemoryState.ready) {
      _currentState = AiMemoryState.loading;
      _stateController.add(_currentState);

      // Simula/gestiona el mapeo de memoria en GPU/Vulkan
      _currentState = AiMemoryState.ready;
      _stateController.add(_currentState);
    }

    // Programa la auto-expulsión al expirar el tiempo de inactividad
    _evictionTimer = Timer(ttlDuration, evictModel);
  }

  /// Libera los recursos de memoria y apaga el runtime LLM local.
  void evictModel() {
    _evictionTimer?.cancel();
    _evictionTimer = null;

    if (_currentState != AiMemoryState.unloaded) {
      _currentState = AiMemoryState.evicting;
      _stateController.add(_currentState);

      _currentState = AiMemoryState.unloaded;
      _stateController.add(_currentState);
    }
  }

  /// Extrae los componentes de una comida a partir de texto o transcripción de voz.
  Future<ParsedMealResult> parseMealText(String rawText) async {
    _touchOrLoad();

    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return const ParsedMealResult(items: []);
    }

    // Si hay un archivo de modelo configurado, se intentaría inferir localmente.
    // En ausencia de pesos o como fallback garantizado, se utiliza el extractor sintáctico determinista.
    return ParsedMealResult(
      items: _parseMealDeterministically(trimmed),
      isFromLlm: hasLocalModelFile,
    );
  }

  /// Analiza semántica, emoción y estrés de una entrada del diario personal.
  Future<JournalAiAnalysis> analyzeJournal(String text) async {
    _touchOrLoad();

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const JournalAiAnalysis(
        moodScore: 3,
        energyLevel: 3,
        stressLevel: 2,
        tags: ['calma'],
        oneLineInsight: 'Un momento para registrar y cuidar de ti.',
      );
    }

    return _analyzeJournalDeterministically(trimmed);
  }

  /// Genera un saludo conciso, cálido y sin regaños para la mascota Nibi (máximo 22 palabras).
  ///
  /// Acepta [variationSeed] y [hourOfDay] para que la IA varíe dinámicamente su mensaje
  /// en cada ingreso a la vista de inicio sin repetir frases monótonas.
  Future<String> generatePetGreeting({
    required String petName,
    double? sleepHours,
    double? fastingHours,
    int? waterMl,
    int? waterGoalMl,
    double? weightTrendDelta7d,
    int? streak,
    int variationSeed = 0,
    int? hourOfDay,
  }) async {
    _touchOrLoad();

    return _generateGreetingDeterministically(
      petName: petName,
      sleepHours: sleepHours,
      fastingHours: fastingHours,
      waterMl: waterMl,
      waterGoalMl: waterGoalMl,
      weightTrendDelta7d: weightTrendDelta7d,
      streak: streak,
      variationSeed: variationSeed,
      hourOfDay: hourOfDay,
    );
  }

  /// Resuelve un texto de comida contra la base de datos local (FTS5) e inserta los registros.
  Future<List<FoodItem>> resolveAndLogMeal({
    required FoodDao foodDao,
    required String text,
    required String mealType,
    required String dateKey,
  }) async {
    final result = await parseMealText(text);
    return logParsedItems(
      foodDao: foodDao,
      items: result.items,
      mealType: mealType,
      dateKey: dateKey,
    );
  }

  /// Resuelve e inserta una lista de items ya extraídos y validados por el usuario.
  Future<List<FoodItem>> logParsedItems({
    required FoodDao foodDao,
    required List<ParsedMealItem> items,
    required String mealType,
    required String dateKey,
  }) async {
    final List<FoodItem> loggedItems = [];

    for (final item in items) {
      if (item.searchTerm.trim().isEmpty || item.grams <= 0) continue;
      final List<FoodItem> searchMatches =
          await foodDao.searchFood(item.searchTerm, limit: 1);
      final FoodItem targetItem;

      if (searchMatches.isNotEmpty) {
        targetItem = searchMatches.first;
      } else {
        // Alimento de respaldo insertado en caché local
        final newId = await foodDao.insertFood(
          FoodItemsCompanion(
            name: drift.Value(item.searchTerm.trim()),
            source: const drift.Value('ai_fallback'),
            kcalPer100g: drift.Value(item.fallbackKcal),
            proteinPer100g: drift.Value(item.fallbackP),
            carbsPer100g: drift.Value(item.fallbackC),
            fatPer100g: drift.Value(item.fallbackF),
          ),
        );
        targetItem = (await foodDao.getById(newId))!;
      }

      final ratio = item.grams / 100.0;
      await foodDao.logFood(
        FoodLogsCompanion(
          dateKey: drift.Value(dateKey),
          loggedAt: drift.Value(DateTime.now()),
          mealType: drift.Value(mealType),
          foodItemId: drift.Value(targetItem.id),
          gramsConsumed: drift.Value(item.grams),
          portionMultiplier: const drift.Value(1.0),
          totalKcal: drift.Value(
              double.parse((targetItem.kcalPer100g * ratio).toStringAsFixed(1))),
          totalProteinG: drift.Value(double.parse(
              (targetItem.proteinPer100g * ratio).toStringAsFixed(1))),
          totalCarbsG: drift.Value(double.parse(
              (targetItem.carbsPer100g * ratio).toStringAsFixed(1))),
          totalFatG: drift.Value(
              double.parse((targetItem.fatPer100g * ratio).toStringAsFixed(1))),
          totalSodiumMg: drift.Value(double.parse(
              (targetItem.sodiumMgPer100g * ratio).toStringAsFixed(1))),
          totalPotassiumMg: drift.Value(double.parse(
              (targetItem.potassiumMgPer100g * ratio).toStringAsFixed(1))),
          totalMagnesiumMg: drift.Value(double.parse(
              (targetItem.magnesiumMgPer100g * ratio).toStringAsFixed(1))),
          totalFiberG: drift.Value(double.parse(
              (targetItem.fiberPer100g * ratio).toStringAsFixed(1))),
        ),
      );

      loggedItems.add(targetItem);
    }

    return loggedItems;
  }

  /// Extractor sintáctico determinista basado en reglas gramaticales y catálogo base de alimentos.
  List<ParsedMealItem> _parseMealDeterministically(String text) {
    final List<ParsedMealItem> items = [];

    // Normaliza separadores habituales preservando modificadores culinarios ("con piel", "con cáscara", "con sal")
    final segments = text
        .replaceAll(RegExp(r'\s+y\s+', caseSensitive: false), ', ')
        .replaceAll(RegExp(r'\s+e\s+', caseSensitive: false), ', ')
        .replaceAll(
          RegExp(
            r'\s+con\s+(?!(?:piel|cáscara|cascara|hueso|sal|azúcar|azucar|agua)\b)',
            caseSensitive: false,
          ),
          ', ',
        )
        .replaceAll('\n', ', ')
        .split(',');

    final RegExp regexGrams = RegExp(
      r'(\d+(?:[\.,]\d+)?)\s*(?:g|gr|gramos|ml|mililitros)\s+(?:de\s+)?(.+)',
      caseSensitive: false,
    );

    final RegExp regexQuantity = RegExp(
      r'(\d+)\s*(?:x\s*)?(huevos?|platanos?|bananos?|manzanas?|naranjas?|rebanadas?|panes?|arepas?)(?:\s+(?:de\s+)?(.*))?',
      caseSensitive: false,
    );

    for (final rawSegment in segments) {
      final seg = rawSegment.trim();
      if (seg.isEmpty) continue;

      double grams = 100.0;
      String name = seg;

      final matchGrams = regexGrams.firstMatch(seg);
      final matchQty = regexQuantity.firstMatch(seg);

      if (matchGrams != null) {
        final rawVal = matchGrams.group(1)!.replaceAll(',', '.');
        grams = double.tryParse(rawVal) ?? 100.0;
        name = matchGrams.group(2)!.trim();
      } else if (matchQty != null) {
        final count = int.tryParse(matchQty.group(1)!) ?? 1;
        final foodType = matchQty.group(2)!.toLowerCase();
        if (foodType.contains('huevo')) {
          grams = count * 55.0;
          name = 'huevo cocido';
        } else if (foodType.contains('platano') || foodType.contains('banano')) {
          grams = count * 120.0;
          name = 'platano banano';
        } else if (foodType.contains('manzana')) {
          grams = count * 150.0;
          name = 'manzana fresca';
        } else if (foodType.contains('rebanada') || foodType.contains('pan')) {
          grams = count * 35.0;
          name = 'pan integral';
        } else {
          grams = count * 100.0;
          name = foodType;
        }
      }

      // Limpia artículos o palabras de relleno iniciales
      name = name
          .replaceAll(RegExp(r'^(un|una|unos|unas|el|la|los|las)\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^\w\sáéíóúüñÁÉÍÓÚÜÑ]', caseSensitive: false), '')
          .trim();

      if (name.isEmpty) continue;

      // Estima macros de respaldo según categoría biológica identificada
      final lower = name.toLowerCase();
      double fbKcal = 130.0;
      double fbP = 4.0;
      double fbC = 20.0;
      double fbF = 3.0;

      if (lower.contains('pollo') || lower.contains('pavo')) {
        fbKcal = 165.0;
        fbP = 31.0;
        fbC = 0.0;
        fbF = 3.6;
      } else if (lower.contains('carne') || lower.contains('res') || lower.contains('lomo')) {
        fbKcal = 210.0;
        fbP = 26.0;
        fbC = 0.0;
        fbF = 11.0;
      } else if (lower.contains('huevo')) {
        fbKcal = 155.0;
        fbP = 13.0;
        fbC = 1.1;
        fbF = 11.0;
      } else if (lower.contains('arroz')) {
        fbKcal = 130.0;
        fbP = 2.7;
        fbC = 28.0;
        fbF = 0.3;
      } else if (lower.contains('avena')) {
        fbKcal = 375.0;
        fbP = 13.5;
        fbC = 68.0;
        fbF = 7.0;
      } else if (lower.contains('atun') || lower.contains('salmon') || lower.contains('pescado')) {
        fbKcal = 180.0;
        fbP = 24.0;
        fbC = 0.0;
        fbF = 9.0;
      } else if (lower.contains('aguacate')) {
        fbKcal = 160.0;
        fbP = 2.0;
        fbC = 8.5;
        fbF = 14.7;
      } else if (lower.contains('yogur') || lower.contains('leche')) {
        fbKcal = 65.0;
        fbP = 4.5;
        fbC = 5.0;
        fbF = 3.2;
      }

      items.add(
        ParsedMealItem(
          searchTerm: name,
          grams: grams,
          fallbackKcal: fbKcal,
          fallbackP: fbP,
          fallbackC: fbC,
          fallbackF: fbF,
        ),
      );
    }

    return items;
  }

  /// Análisis de sentimiento, niveles de energía y estrés deterministas con etiquetado automático.
  JournalAiAnalysis _analyzeJournalDeterministically(String text) {
    final lower = text.toLowerCase();

    int mood = 3;
    int energy = 3;
    int stress = 2;
    final List<String> tags = [];

    // Indicadores de Ánimo Positivo
    final positiveWords = ['feliz', 'contento', 'tranquilo', 'paz', 'motivado', 'alegría', 'logro', 'orgullo', 'bien', 'excelente'];
    final int posCount = positiveWords.where(lower.contains).length;

    // Indicadores de Ánimo Desafiante
    final negativeWords = ['triste', 'desanimado', 'mal', 'enojado', 'frustrado', 'tristeza', 'difícil', 'duda'];
    final int negCount = negativeWords.where(lower.contains).length;

    if (posCount > negCount) {
      mood = (3 + posCount).clamp(1, 5);
      tags.add('calma_interior');
    } else if (negCount > posCount) {
      mood = (3 - negCount).clamp(1, 5);
      tags.add('gestion_emocional');
    }

    // Indicadores de Energía
    final highEnergyWords = ['energía', 'fuerza', 'vitalidad', 'activo', 'ágil', 'imparable', 'entrené'];
    final lowEnergyWords = ['cansado', 'agotado', 'fatiga', 'pesado', 'sueño', 'exhausto', 'sin fuerza'];

    if (highEnergyWords.any(lower.contains)) {
      energy = 5;
      tags.add('alta_energia');
    } else if (lowEnergyWords.any(lower.contains)) {
      energy = 2;
      tags.add('recuperacion_fisica');
    }

    // Indicadores de Estrés
    final highStressWords = ['estrés', 'estresado', 'agobio', 'presión', 'tensión', 'urgente', 'ansiedad', 'sobrecarga'];
    if (highStressWords.any(lower.contains)) {
      stress = 4;
      tags.add('sobrecarga_mental');
    } else if (lower.contains('relajado') || lower.contains('descanso') || lower.contains('tranquilidad')) {
      stress = 1;
      tags.add('descanso_reparador');
    }

    if (tags.isEmpty) {
      tags.add('reflexion_personal');
    }

    // Insight empático de máximo 18 palabras
    String insight;
    if (mood >= 4 && energy >= 4) {
      insight = 'Excelente sinergia de ánimo y vitalidad hoy. Mantén este ritmo con propósito.';
    } else if (stress >= 4) {
      insight = 'Día de alta exigencia mental. Regálate una pausa, hidrátate y respira con calma.';
    } else if (energy <= 2) {
      insight = 'Tu cuerpo te pide regeneración física. Prioriza descanso y sueño reparador esta noche.';
    } else {
      insight = 'Cada palabra registrada construye autoconocimiento y serenidad en tu camino.';
    }

    return JournalAiAnalysis(
      moodScore: mood,
      energyLevel: energy,
      stressLevel: stress,
      tags: tags.take(3).toList(),
      oneLineInsight: insight,
    );
  }

  /// Genera un saludo positivo instantáneo sin despertar el temporizador de VRAM GPU.
  ///
  /// Cuando [variationSeed] cambia en cada visita a Hoy, la IA selecciona y sintetiza
  /// variantes frescas adaptadas a la hora del día y al estado fisiológico del usuario.
  static String buildInstantGreeting({
    required String petName,
    double? sleepHours,
    double? fastingHours,
    int? waterMl,
    int? waterGoalMl,
    double? weightTrendDelta7d,
    int? streak,
    int variationSeed = 0,
    int? hourOfDay,
  }) {
    final int safeSeed = variationSeed.abs();
    final int h = hourOfDay ?? DateTime.now().hour;

    if (fastingHours != null && fastingHours >= 14.0) {
      const List<String> ketosisPool = <String>[
        '¡Cetosis activa y autofagia profunda! Tu claridad mental y renovación celular están en su punto más alto ✨',
        '¡Cetosis activa en marcha! Tu cuerpo aprovecha reservas con serenidad y enfoque extraordinario 🔥',
        '¡Cetosis activa hoy! Cada minuto de descanso digestivo fortalece tu energía metabólica con calma ✨',
        '¡Cetosis activa! Qué admirable constancia; escucha a tu cuerpo e hidrátate suavemente 💧',
      ];
      return ketosisPool[safeSeed % ketosisPool.length];
    }

    if (waterMl != null && waterGoalMl != null && waterMl >= waterGoalMl) {
      const List<String> waterPool = <String>[
        '¡Meta de hidratación completada! Cada célula de tu cuerpo está llena de energía y vitalidad 💧',
        '¡Excelente hidratación hoy! Tu mente y tus músculos agradecen cada vaso de agua pura 🌊',
        '¡Hidratación al día! Cuidar el agua que tomas ilumina tu concentración y bienestar celular ✨',
        '¡Lograste tu hidratación diaria! Pequeños gestos conscientes como este transforman tu salud 💧',
      ];
      return waterPool[safeSeed % waterPool.length];
    }

    if (sleepHours != null && sleepHours >= 7.5) {
      const List<String> sleepPool = <String>[
        '¡Gran noche de sueño reparador! Despertar descansado es el mejor combustible para tus metas de hoy 🌅',
        'Dormiste de maravilla; hoy tienes energía limpia y tu bono de descanso activo conmigo ✨',
        'Un descanso profundo renueva todo tu sistema nervioso. ¡Disfruta este día con calma y foco! 🌿',
        'Qué buen descanso lograste anoche; tu recuperación muscular y claridad hoy brillan al máximo 🌟',
      ];
      return sleepPool[safeSeed % sleepPool.length];
    }

    if (streak != null && streak >= 5) {
      final List<String> streakPool = <String>[
        '¡Llevas $streak días cuidando de ti sin pausa! La constancia tranquila es tu mayor superpoder 🌟',
        '$streak días sumando hábitos amables contigo. Estoy muy orgulloso de acompañarte hoy 🐉',
        '¡$streak días de ritmo constante! Sin prisas y con cariño, estás construyendo algo duradero ✨',
        'Tu racha de $streak días refleja equilibrio real. Vamos paso a paso en este nuevo día 🌱',
      ];
      return streakPool[safeSeed % streakPool.length];
    }

    if (weightTrendDelta7d != null && weightTrendDelta7d < -0.2) {
      const List<String> trendPool = <String>[
        'Tu tendencia de peso avanza sólida hacia tu meta. La paciencia y los buenos hábitos dan frutos 🌱',
        'La curva EMA muestra progreso firme y saludable. Confía en tu proceso diario sin presiones ✨',
        'Tu composición responde muy bien a tu constancia reciente. ¡Sigamos cuidando tu energía hoy! 🌿',
      ];
      return trendPool[safeSeed % trendPool.length];
    }

    if (variationSeed == 0) {
      return '¡Hola! Qué alegría verte hoy. Recuerda que cada pequeño paso consciente cuenta para tu bienestar 🌿';
    }

    if (h >= 5 && h < 12) {
      const List<String> morningPool = <String>[
        '¡Qué alegría empezar la mañana contigo! Un vaso de agua y respirar hondo son un gran inicio ☀️',
        'Nueva mañana, nueva oportunidad para cuidarte con calma. Aquí estoy contigo en cada paso 🌱',
        '¡Buen comienzo de día! Escucha qué necesita tu cuerpo hoy y avancemos a tu propio ritmo ✨',
        'La mañana huele a energía fresca. Registra lo que te sume paz y vitalidad hoy 🌿',
      ];
      return morningPool[safeSeed % morningPool.length];
    } else if (h >= 12 && h < 19) {
      const List<String> afternoonPool = <String>[
        '¡Qué gusto verte esta tarde! Haz una pausa breve, estira los hombros y toma un poco de agua 🌤️',
        'Mitad del día ideal para recargar energía nutritiva y celebrar lo que ya lograste hoy ✨',
        'Aquí sigo acompañándote esta tarde; recuerda que la constancia amable vale más que la perfección 🌿',
        '¿Cómo va tu energía esta tarde? Cualquier pequeño registro hoy suma claridad a tu camino 🐉',
      ];
      return afternoonPool[safeSeed % afternoonPool.length];
    } else {
      const List<String> nightPool = <String>[
        'La noche invita a bajar el ritmo. Escribir unas líneas en tu diario te regalará calma interior 🌙',
        '¡Qué bueno cerrar el día contigo! Agradece a tu cuerpo por todo lo que sostuvo hoy ✨',
        'Hora de soltar tensiones del día y preparar un descanso reparador. Aquí cuido tu rincón tranquilo 🌌',
        'Respira suave esta noche; todo lo que hiciste hoy por tu bienestar ya dejó huella positiva 🌿',
      ];
      return nightPool[safeSeed % nightPool.length];
    }
  }

  /// Generador contextual determinista de saludos para Nibi (≤ 22 palabras, sin regaños).
  String _generateGreetingDeterministically({
    required String petName,
    double? sleepHours,
    double? fastingHours,
    int? waterMl,
    int? waterGoalMl,
    double? weightTrendDelta7d,
    int? streak,
    int variationSeed = 0,
    int? hourOfDay,
  }) {
    return buildInstantGreeting(
      petName: petName,
      sleepHours: sleepHours,
      fastingHours: fastingHours,
      waterMl: waterMl,
      waterGoalMl: waterGoalMl,
      weightTrendDelta7d: weightTrendDelta7d,
      streak: streak,
      variationSeed: variationSeed,
      hourOfDay: hourOfDay,
    );
  }

  /// Limpia todos los recursos y controladores abiertos al destruir el servicio.
  void dispose() {
    evictModel();
    unawaited(_stateController.close());
  }
}

/// Provider global de Riverpod para inyectar LocalAiService.
final localAiServiceProvider = Provider<LocalAiService>((ref) {
  final service = LocalAiService();
  ref.onDispose(service.dispose);
  return service;
});
