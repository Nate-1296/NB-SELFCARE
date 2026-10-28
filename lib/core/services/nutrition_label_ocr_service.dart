import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Datos nutricionales extraídos mediante OCR local desde una tabla de información nutricional.
class OcrNutritionData {
  const OcrNutritionData({
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
    this.servingGrams,
    this.rawText = '',
  });

  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;
  final double? servingGrams;
  final String rawText;

  bool get hasAnyData =>
      kcal != null || proteinG != null || carbsG != null || fatG != null;
}

/// Servicio de reconocimiento óptico de caracteres (OCR) 100% On-Device
/// para tablas de información nutricional de alimentos.
class NutritionLabelOcrService {
  /// Procesa una imagen tomada por la cámara o galería y extrae los macronutrientes.
  Future<OcrNutritionData> processImage(XFile imageFile) async {
    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText =
          await recognizer.processImage(inputImage);
      return parseText(recognizedText.text);
    } catch (_) {
      return const OcrNutritionData();
    } finally {
      unawaited(recognizer.close());
    }
  }

  /// Parsea el texto crudo de la etiqueta nutricional usando expresiones regulares tolerantes.
  OcrNutritionData parseText(String rawText) {
    if (rawText.trim().isEmpty) {
      return const OcrNutritionData();
    }

    // Las etiquetas europeas ponen "1500 kJ / 359 kcal": primero se busca una
    // cifra seguida de "kcal"; si solo hay kJ, se convierte.
    double? kcal = _extractRegex(rawText, RegExp(r'(\d+(?:[.,]\d+)?)\s*kcal', caseSensitive: false));
    if (kcal == null) {
      final RegExpMatch? energy = RegExp(
        r'(?:calor[ií]as|energ[ií]a|energy|calories|valor\s*energ[eé]tico)\D{0,15}?(\d+(?:[.,]\d+)?)\s*(kj)?',
        caseSensitive: false,
      ).firstMatch(rawText);
      final double? value = double.tryParse(energy?.group(1)?.replaceAll(',', '.') ?? '');
      if (value != null) kcal = energy!.group(2) == null ? value : value / 4.184;
    }

    final double? protein = _extractRegex(
      rawText,
      RegExp(
        r'(?:prote[ií]nas?|proteins?)\D{0,15}?(\d+(?:[.,]\d+)?)\s*g?',
        caseSensitive: false,
      ),
    );

    final double? fat = _extractRegex(
      rawText,
      RegExp(
        r'(?:grasas?\s*totales?|total\s*fat|grasas?|fat|l[ií]pidos?)\D{0,15}?(\d+(?:[.,]\d+)?)\s*g?',
        caseSensitive: false,
      ),
    );

    final double? carbs = _extractRegex(
      rawText,
      RegExp(
        r'(?:carbohidratos?\s*totales?|hidratos\s*de\s*carbono|total\s*carbohydrate|carbs?)\D{0,15}?(\d+(?:[.,]\d+)?)\s*g?',
        caseSensitive: false,
      ),
    );

    final double? fiber = _extractRegex(
      rawText,
      RegExp(
        r'(?:fibra\s*diet[eé]tica|dietary\s*fiber|fibra|fiber)\D{0,15}?(\d+(?:[.,]\d+)?)\s*g?',
        caseSensitive: false,
      ),
    );

    final double? sugar = _extractRegex(
      rawText,
      RegExp(
        r'(?:az[uú]cares?\s*totales?|total\s*sugars?|az[uú]cares?|sugars?)\D{0,15}?(\d+(?:[.,]\d+)?)\s*g?',
        caseSensitive: false,
      ),
    );

    double? sodiumMg = _extractSodium(rawText);
    if (sodiumMg == null) {
      // Intentar extraer sal y convertir a sodio: 1g sal ≈ 400mg sodio
      final double? saltG = _extractRegex(
        rawText,
        RegExp(
          r'(?:sal|salt)\D{0,15}?(\d+(?:[.,]\d+)?)\s*g?',
          caseSensitive: false,
        ),
      );
      if (saltG != null) {
        sodiumMg = double.parse((saltG * 400.0).toStringAsFixed(1));
      }
    }

    final double? servingG = _extractRegex(
      rawText,
      RegExp(
        r'(?:porci[oó]n|tama[ñn]o\s*de\s*la\s*porci[oó]n|serving\s*size)\D{0,15}?(\d+(?:[.,]\d+)?)\s*g?',
        caseSensitive: false,
      ),
    );

    // Un error de reconocimiento (un "8" de más, una coma perdida) no debe
    // llegar al formulario como una cifra imposible: se deja el campo vacío.
    double? plausible(double? v, double max) => v != null && v.isFinite && v >= 0 && v <= max ? v : null;

    return OcrNutritionData(
      kcal: plausible(kcal, 9000),
      proteinG: plausible(protein, 1000),
      carbsG: plausible(carbs, 1000),
      fatG: plausible(fat, 1000),
      fiberG: plausible(fiber, 1000),
      sugarG: plausible(sugar, 1000),
      sodiumMg: plausible(sodiumMg, 100000),
      servingGrams: plausible(servingG, 5000),
      rawText: rawText,
    );
  }

  double? _extractSodium(String text) {
    final RegExp match = RegExp(
      r'(?:sodio|sodium)\D{0,15}?(\d+(?:[.,]\d+)?)\s*(mg|g)?',
      caseSensitive: false,
    );
    final RegExpMatch? m = match.firstMatch(text);
    if (m == null) return null;

    final String? numStr = m.group(1);
    if (numStr == null) return null;
    final double? val = double.tryParse(numStr.replaceAll(',', '.'));
    if (val == null) return null;

    final String? unit = m.group(2)?.toLowerCase();
    if (unit == 'g') {
      return double.parse((val * 1000.0).toStringAsFixed(1));
    }
    return double.parse(val.toStringAsFixed(1));
  }

  double? _extractRegex(String text, RegExp regExp) {
    final RegExpMatch? m = regExp.firstMatch(text);
    if (m == null) return null;
    final String? numStr = m.group(1);
    if (numStr == null) return null;
    final double? val = double.tryParse(numStr.replaceAll(',', '.'));
    return val != null ? double.parse(val.toStringAsFixed(1)) : null;
  }
}

/// Provider de Riverpod para inyectar NutritionLabelOcrService.
final nutritionLabelOcrServiceProvider =
    Provider<NutritionLabelOcrService>((ref) {
  return NutritionLabelOcrService();
});

