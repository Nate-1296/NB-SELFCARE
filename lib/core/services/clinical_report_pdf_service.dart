import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/utils/biometric_formulas.dart';
import '../../shared/utils/number_formats.dart';
import '../clock/clock.dart';
import '../database/app_database.dart';
import '../domain/enums.dart';
import 'smart_meal_suggester.dart';

/// Servicio de generación de informes clínicos en formato PDF 100% offline.
class ClinicalReportPdfService {
  ClinicalReportPdfService({this._clock = const Clock()});

  final Clock _clock;

  /// Genera un documento PDF formal (A4) con las métricas de composición corporal,
  /// nutrición, cronobiología y adherencia a suplementos.
  Future<Uint8List> generateReportBytes({
    required UserProfile profile,
    required BodyMeasurement? latestMeasurement,
    required List<BodyMeasurement> recentMeasurements,
    required int averageDailyKcal,
    required int foodDays,
    required double averageProteinG,
    required double averageCarbsG,
    required double averageFatG,
    required double averageSleepHours,
    required List<SupplementsTrackerData> activeSupplements,
    required int? readinessScore,
    List<String> vitalsSummary = const <String>[],
    List<String> symptomsSummary = const <String>[],
  }) async {
    final pw.Document pdf = pw.Document(title: 'Informe de salud personal', author: 'NB Selfcare');

    final DateTime now = _clock.now();
    // Años cumplidos (24, no "25,0" a una semana del cumpleaños).
    final int age = BiometricFormulas.calculateDynamicAge(profile.birthDate, now).floor();
    final String dateStr = _longDate(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              // Encabezado institucional
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        'Informe de salud personal',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Generado en el teléfono con NB Selfcare. Ningún dato sale del dispositivo.',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                      ),
                    ],
                  ),
                  pw.Text(
                    dateStr,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.blueGrey300, thickness: 1),
              pw.SizedBox(height: 10),

              // 1. Datos Demográficos y Objetivos
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    _pdfField('Nombre', profile.name),
                    _pdfField('Edad', '$age años'),
                    _pdfField(
                      'Sexo biológico',
                      profile.biologicalSex == BiologicalSex.female ? 'Femenino' : 'Masculino',
                    ),
                    _pdfField('Estatura', '${NumberFormats.fixed(profile.heightCm, 0)} cm'),
                    _pdfField('Peso meta', '${NumberFormats.fixed(profile.targetWeightKg, 1)} kg'),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 2. Composición Corporal (Báscula BIA + Tendencia EMA)
              pw.Text(
                '1. Composición corporal',
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: <pw.TableRow>[
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: <pw.Widget>[
                      _tableHeader('Medida'),
                      _tableHeader('Último valor'),
                      _tableHeader('Tendencia'),
                      _tableHeader('Referencia'),
                    ],
                  ),
                  _tableRow(
                    'Peso',
                    latestMeasurement != null
                        ? '${NumberFormats.fixed(latestMeasurement.weightKg, 1)} kg'
                        : 'N/D',
                    latestMeasurement != null
                        ? '${NumberFormats.fixed(latestMeasurement.trendWeightKg, 1)} kg'
                        : 'N/D',
                    'IMC: ${latestMeasurement == null ? "N/D" : NumberFormats.fixed(latestMeasurement.bmi, 1)}',
                  ),
                  _tableRow(
                    'Grasa corporal',
                    latestMeasurement?.bodyFatPercentage != null
                        ? '${NumberFormats.fixed(latestMeasurement!.bodyFatPercentage!, 1)} %'
                        : 'N/D',
                    '-',
                    'Grasa visceral: ${latestMeasurement?.visceralFatIndex ?? "N/D"}',
                  ),
                  _tableRow(
                    'Masa muscular',
                    latestMeasurement?.muscleMassKg != null
                        ? '${NumberFormats.fixed(latestMeasurement!.muscleMassKg!, 1)} kg'
                        : 'N/D',
                    '-',
                    'Masa libre de grasa: ${latestMeasurement?.leanBodyMassKg == null ? "N/D" : NumberFormats.fixed(latestMeasurement!.leanBodyMassKg!, 1)} kg',
                  ),
                  _tableRow(
                    'Agua corporal',
                    latestMeasurement?.waterPercentage != null
                        ? '${NumberFormats.fixed(latestMeasurement!.waterPercentage!, 1)} %'
                        : 'N/D',
                    '-',
                    'Rango habitual: 50–65 %',
                  ),
                  _tableRow(
                    'Metabolismo basal',
                    latestMeasurement?.basalMetabolicRateKcal != null
                        ? '${NumberFormats.group(latestMeasurement!.basalMetabolicRateKcal!)} kcal'
                        : 'N/D',
                    '-',
                    'Edad metabólica: ${latestMeasurement?.metabolicAge ?? "N/D"} años',
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 3. Nutrición & Perfil de Macronutrientes
              pw.Text(
                '2. Alimentación (media de los días con registro, últimos 7 días)',
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    _pdfField('Energía', '${NumberFormats.group(averageDailyKcal)} kcal/día'),
                    _pdfField('Proteína', '${NumberFormats.fixed(averageProteinG, 0)} g/día'),
                    _pdfField('Carbohidratos', '${NumberFormats.fixed(averageCarbsG, 0)} g/día'),
                    _pdfField('Grasas', '${NumberFormats.fixed(averageFatG, 0)} g/día'),
                    _pdfField(
                      'Estilo',
                      DietArchetypeInfo.getById(profile.activeDietArchetype).name,
                    ),
                    _pdfField('Días con registro', '$foodDays de 7'),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 4. Cronobiología, Recuperación & Suplementación
              pw.Text(
                '3. Descanso y suplementos',
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: <pw.Widget>[
                        _pdfField(
                          'Sueño medio',
                          averageSleepHours > 0
                              ? '${NumberFormats.fixed(averageSleepHours, 1)} h/noche'
                              : 'Sin registros',
                        ),
                        _pdfField(
                          'Disposición de hoy',
                          readinessScore == null ? 'Sin sueño registrado' : '$readinessScore / 100',
                        ),
                        if (profile.biologicalSex == BiologicalSex.female)
                          _pdfField(
                            'Seguimiento del ciclo',
                            profile.isCycleTrackingEnabled ? 'Activo' : 'Inactivo',
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Medicamentos y suplementos',
                      style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      activeSupplements.isEmpty
                          ? 'Ninguno.'
                          : activeSupplements.map((s) => '- ${s.name} (${s.dosage})').join('   '),
                      style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
                    ),
                    if (vitalsSummary.isNotEmpty) ...<pw.Widget>[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Signos vitales (últimos 30 días)',
                        style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        vitalsSummary.join('\n'),
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
                      ),
                    ],
                    if (symptomsSummary.isNotEmpty) ...<pw.Widget>[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Síntomas más frecuentes (últimos 30 días)',
                        style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        symptomsSummary.join('   '),
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
                      ),
                    ],
                  ],
                ),
              ),

              pw.Spacer(),

              // Descargo médico
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Aviso: este documento resume registros personales y estimaciones por bioimpedancia (BIA). '
                  'No es un diagnóstico médico ni sustituye el criterio de un profesional de la salud.',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Una línea por signo vital: media, rango y número de mediciones.
  static List<String> summarizeVitals(List<VitalReading> readings) {
    const Map<String, (String, String)> names = <String, (String, String)>{
      'blood_pressure': ('Tensión arterial', 'mmHg'),
      'glucose': ('Glucosa', 'mg/dL'),
      'oxygen': ('Oxígeno en sangre', '%'),
      'temperature': ('Temperatura', '°C'),
    };
    final List<String> lines = <String>[];
    for (final MapEntry<String, (String, String)> e in names.entries) {
      final List<VitalReading> rows = readings.where((VitalReading r) => r.kind == e.key).toList();
      if (rows.isEmpty) continue;
      double mean(Iterable<double> v) => v.reduce((double a, double b) => a + b) / v.length;
      final double p = mean(rows.map((VitalReading r) => r.primaryValue));
      final List<double> secondary = rows
          .map((VitalReading r) => r.secondaryValue)
          .whereType<double>()
          .toList();
      final String value = e.key == 'blood_pressure' && secondary.isNotEmpty
          ? '${p.round()}/${mean(secondary).round()}'
          : (e.key == 'temperature' ? NumberFormats.fixed(p, 1) : '${p.round()}');
      lines.add('- ${e.value.$1}: media $value ${e.value.$2} (${rows.length} mediciones)');
    }
    return lines;
  }

  /// "28 de octubre de 2026" sin depender de los datos de idioma de intl
  /// (el servicio también se usa fuera de la app, en pruebas).
  static String _longDate(DateTime d) {
    const List<String> months = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${d.day} de ${months[d.month - 1]} de ${d.year}';
  }

  /// Despliega el visor de impresión nativo o comparte el PDF.
  Future<void> shareOrPrintReport({
    required UserProfile profile,
    required BodyMeasurement? latestMeasurement,
    required List<BodyMeasurement> recentMeasurements,
    required int averageDailyKcal,
    required int foodDays,
    required double averageProteinG,
    required double averageCarbsG,
    required double averageFatG,
    required double averageSleepHours,
    required List<SupplementsTrackerData> activeSupplements,
    required int? readinessScore,
    List<String> vitalsSummary = const <String>[],
    List<String> symptomsSummary = const <String>[],
  }) async {
    final Uint8List pdfBytes = await generateReportBytes(
      profile: profile,
      latestMeasurement: latestMeasurement,
      recentMeasurements: recentMeasurements,
      averageDailyKcal: averageDailyKcal,
      foodDays: foodDays,
      averageProteinG: averageProteinG,
      averageCarbsG: averageCarbsG,
      averageFatG: averageFatG,
      averageSleepHours: averageSleepHours,
      activeSupplements: activeSupplements,
      readinessScore: readinessScore,
      vitalsSummary: vitalsSummary,
      symptomsSummary: symptomsSummary,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          'reporte_clinico_${profile.name.replaceAll(" ", "_").toLowerCase()}_${_clock.now().toIso8601String().split("T").first}.pdf',
    );
  }

  static pw.Widget _pdfField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.TableRow _tableRow(String metric, String current, String ema, String reference) {
    return pw.TableRow(
      children: <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(metric, style: const pw.TextStyle(fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            current,
            style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(ema, style: const pw.TextStyle(fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            reference,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }
}

/// Provider de Riverpod para ClinicalReportPdfService.
final clinicalReportPdfServiceProvider = Provider<ClinicalReportPdfService>((ref) {
  return ClinicalReportPdfService(clock: ref.watch(clockProvider));
});
