import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/utils/biometric_formulas.dart';
import '../database/app_database.dart';

/// Servicio de generación de informes clínicos en formato PDF 100% offline.
class ClinicalReportPdfService {
  /// Genera un documento PDF formal (A4) con las métricas de composición corporal,
  /// nutrición, cronobiología y adherencia a suplementos.
  Future<Uint8List> generateReportBytes({
    required UserProfile profile,
    required BodyMeasurement? latestMeasurement,
    required List<BodyMeasurement> recentMeasurements,
    required int averageDailyKcal,
    required double averageProteinG,
    required double averageCarbsG,
    required double averageFatG,
    required double averageSleepHours,
    required List<SupplementsTrackerData> activeSupplements,
    required int readinessScore,
  }) async {
    final pw.Document pdf = pw.Document(
      title: 'NB Selfcare - Reporte Clinico y Fisiologico',
      author: 'NB Selfcare Offline Health Engine',
    );

    final double age = BiometricFormulas.calculateDynamicAge(profile.birthDate);
    final String dateStr = DateTime.now().toIso8601String().split('T').first;

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
                        'NB SELFCARE - REPORTE DE SALUD PERSONAL',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Motor Biométrico & Nutricional Autónomo (100% Offline / Zero Telemetry)',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Fecha: $dateStr',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.blueGrey700,
                    ),
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
                    _pdfField('Usuario', profile.name),
                    _pdfField('Edad', '${age.toStringAsFixed(1)} años'),
                    _pdfField('Sexo biológico', profile.biologicalSex == 'female' ? 'Femenino' : 'Masculino'),
                    _pdfField('Altura', '${profile.heightCm.toStringAsFixed(1)} cm'),
                    _pdfField('Meta de Peso', '${profile.targetWeightKg.toStringAsFixed(1)} kg'),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 2. Composición Corporal (Báscula BIA + Tendencia EMA)
              pw.Text(
                '1. COMPOSICIÓN CORPORAL & TENDENCIA',
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: <pw.TableRow>[
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: <pw.Widget>[
                      _tableHeader('Métrica Fisiológica'),
                      _tableHeader('Valor Actual'),
                      _tableHeader('Tendencia EMA'),
                      _tableHeader('Referencia / Estado'),
                    ],
                  ),
                  _tableRow(
                    'Peso Corporal Total',
                    latestMeasurement != null ? '${latestMeasurement.weightKg.toStringAsFixed(1)} kg' : 'N/D',
                    latestMeasurement != null ? '${latestMeasurement.trendWeightKg.toStringAsFixed(1)} kg' : 'N/D',
                    'IMC: ${latestMeasurement?.bmi.toStringAsFixed(1) ?? "N/D"}',
                  ),
                  _tableRow(
                    'Porcentaje de Grasa Corporal',
                    latestMeasurement?.bodyFatPercentage != null ? '${latestMeasurement!.bodyFatPercentage!.toStringAsFixed(1)} %' : 'N/D',
                    '-',
                    'Grasa Visceral: ${latestMeasurement?.visceralFatIndex ?? "N/D"}',
                  ),
                  _tableRow(
                    'Masa Muscular Esquelética',
                    latestMeasurement?.muscleMassKg != null ? '${latestMeasurement!.muscleMassKg!.toStringAsFixed(1)} kg' : 'N/D',
                    '-',
                    'Masa Libre de Grasa: ${latestMeasurement?.leanBodyMassKg?.toStringAsFixed(1) ?? "N/D"} kg',
                  ),
                  _tableRow(
                    'Agua Corporal Total (BIA)',
                    latestMeasurement?.waterPercentage != null ? '${latestMeasurement!.waterPercentage!.toStringAsFixed(1)} %' : 'N/D',
                    '-',
                    'Fisiológico normal: 50% - 65%',
                  ),
                  _tableRow(
                    'Tasa Metabólica Basal (BMR)',
                    latestMeasurement?.basalMetabolicRateKcal != null ? '${latestMeasurement!.basalMetabolicRateKcal} kcal' : 'N/D',
                    '-',
                    'Edad Metabólica: ${latestMeasurement?.metabolicAge ?? "N/D"} años',
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 3. Nutrición & Perfil de Macronutrientes
              pw.Text(
                '2. PROMEDIO NUTRICIONAL & ENERGÍA (7 DÍAS)',
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
                    _pdfField('Ingesta Media', '$averageDailyKcal kcal/día'),
                    _pdfField('Proteína', '${averageProteinG.toStringAsFixed(0)} g/día'),
                    _pdfField('Carbohidratos', '${averageCarbsG.toStringAsFixed(0)} g/día'),
                    _pdfField('Grasas', '${averageFatG.toStringAsFixed(0)} g/día'),
                    _pdfField('Arquetipo', profile.activeDietArchetype.toUpperCase()),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 4. Cronobiología, Recuperación & Suplementación
              pw.Text(
                '3. CRONOBIOLOGÍA, RECUPERACIÓN & SUPLEMENTOS',
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
                        _pdfField('Sueño Promedio', '${averageSleepHours.toStringAsFixed(1)} horas/noche'),
                        _pdfField('Disposición (Readiness)', '$readinessScore / 100 pts'),
                        _pdfField('Ciclo Femenino', profile.biologicalSex == 'female' ? (profile.isCycleTrackingEnabled ? 'Activo' : 'Inactivo') : 'N/A'),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Pauta de Suplementación Activa:',
                      style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      activeSupplements.isEmpty
                          ? 'Ningún suplemento activo registrado.'
                          : activeSupplements.map((s) => '- ${s.name} (${s.dosage})').join('   '),
                      style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.blueGrey800),
                    ),
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
                  'AVISO CLÍNICO LEGAL: Este documento es un resumen de registros personales, hábitos de estilo de vida '
                  'y estimaciones mediante bioimpedancia eléctrica (BIA). No constituye un diagnóstico médico formal ni '
                  'reemplaza el criterio clínico o de laboratorio de un profesional de la salud colegiado.',
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

  /// Despliega el visor de impresión nativo o comparte el PDF.
  Future<void> shareOrPrintReport({
    required UserProfile profile,
    required BodyMeasurement? latestMeasurement,
    required List<BodyMeasurement> recentMeasurements,
    required int averageDailyKcal,
    required double averageProteinG,
    required double averageCarbsG,
    required double averageFatG,
    required double averageSleepHours,
    required List<SupplementsTrackerData> activeSupplements,
    required int readinessScore,
  }) async {
    final Uint8List pdfBytes = await generateReportBytes(
      profile: profile,
      latestMeasurement: latestMeasurement,
      recentMeasurements: recentMeasurements,
      averageDailyKcal: averageDailyKcal,
      averageProteinG: averageProteinG,
      averageCarbsG: averageCarbsG,
      averageFatG: averageFatG,
      averageSleepHours: averageSleepHours,
      activeSupplements: activeSupplements,
      readinessScore: readinessScore,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'reporte_clinico_${profile.name.replaceAll(" ", "_").toLowerCase()}_${DateTime.now().toIso8601String().split("T").first}.pdf',
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
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
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
          child: pw.Text(current, style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(ema, style: const pw.TextStyle(fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(reference, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ),
      ],
    );
  }
}

/// Provider de Riverpod para ClinicalReportPdfService.
final clinicalReportPdfServiceProvider =
    Provider<ClinicalReportPdfService>((ref) {
  return ClinicalReportPdfService();
});
