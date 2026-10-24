import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/health_sync_dao.dart';
import '../../../../core/database/daos/pet_dao.dart';
import '../../../../core/services/health_connect_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/daily_targets_calculator.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../body_metrics/presentation/widgets/quick_rpe_workout_sheet.dart';
import '../../../pet_gamification/presentation/shop_modal.dart';
import '../../domain/hoy_widget_config.dart';

// ============================================================================
// 1. WIDGET COMPAÑERO NIBI (IA CONTEXTUAL VARIABLE) — 4×2 / 2×2
// ============================================================================
class HoyNibiBentoCard extends StatelessWidget {
  const HoyNibiBentoCard({
    super.key,
    required this.size,
    required this.petName,
    required this.coinsBalance,
    required this.streakDays,
    required this.aiGreeting,
    required this.isKetosis,
    required this.hasSleepBonus,
    required this.onRefreshGreeting,
  });

  final HoyWidgetSize size;
  final String petName;
  final int coinsBalance;
  final int streakDays;
  final String aiGreeting;
  final bool isKetosis;
  final bool hasSleepBonus;
  final VoidCallback onRefreshGreeting;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool compact = size.isHalfWidth;

    final Widget avatar = GestureDetector(
      onTap: () => context.go('/nibi'),
      child: Container(
        width: compact ? 50 : 58,
        height: compact ? 50 : 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.soft,
          border: Border.all(
            color: c.isFlat ? c.line2 : c.accent,
            width: c.isFlat ? 1.8 : 1.5,
          ),
          image: const DecorationImage(
            image: AssetImage('assets/images/nibi_avatar.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    final Widget badgesWrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        ChipPill(
          icon: AppIcons.moneda,
          iconColor: c.isFlat ? c.text : c.warning,
          label: '$coinsBalance',
          onTap: () => ShopModal.show(context),
        ),
        ChipPill(
          icon: AppIcons.racha,
          iconColor: c.isFlat ? c.text : c.calories,
          label: '${streakDays}d',
          onTap: () => context.go('/nibi'),
        ),
      ],
    );

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (compact) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                avatar,
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Nuevo pensamiento IA de $petName',
                  onPressed: onRefreshGreeting,
                  icon: Icon(AppIcons.chispa, size: 18, color: c.accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              petName,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            badgesWrap,
            const SizedBox(height: 10),
            Text(
              aiGreeting,
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.text2,
                height: 1.38,
              ),
            ),
          ] else ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                avatar,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: <Widget>[
                          GestureDetector(
                            onTap: () => context.go('/nibi'),
                            child: Text(
                              petName,
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: ScFonts.display,
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: c.text,
                              ),
                            ),
                          ),
                          badgesWrap,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: c.isFlat ? c.line2 : c.line,
                            width: c.isFlat ? 1.3 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                aiGreeting,
                                softWrap: true,
                                style: TextStyle(
                                  fontFamily: ScFonts.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: c.text,
                                  height: 1.38,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: onRefreshGreeting,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  AppIcons.chispa,
                                  size: 17,
                                  color: c.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (isKetosis || hasSleepBonus) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                if (isKetosis)
                  _StatusTag(
                    icon: AppIcons.chispa,
                    label: 'Cetosis activa ✨',
                    color: c.fasting,
                  ),
                if (hasSleepBonus)
                  _StatusTag(
                    icon: AppIcons.sueno,
                    label: 'Bono Sueño x1.5 🪙',
                    color: c.accent,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/nibi'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              icon: Icon(AppIcons.nibi, size: 16, color: c.accent),
              label: Text(
                'Ir al Santuario de $petName',
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. WIDGET OBJETIVOS DEL DÍA (CALORÍAS + MACROS + ACCIONES DE COMIDA) — 4×2 / 2×2
// ============================================================================
class HoyNutritionBentoCard extends StatelessWidget {
  const HoyNutritionBentoCard({
    super.key,
    required this.size,
    required this.consumedKcal,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    required this.targets,
    required this.onRepeatYesterday,
  });

  final HoyWidgetSize size;
  final double consumedKcal;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;
  final DailyMacroTargets targets;
  final VoidCallback onRepeatYesterday;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool compact = size.isHalfWidth;

    final int effectiveGoalKcal = targets.effectiveCalorieTargetKcal;
    final int remainingKcal = effectiveGoalKcal - consumedKcal.round();
    final double kcalRatio = effectiveGoalKcal > 0
        ? (consumedKcal / effectiveGoalKcal).clamp(0.0, 1.0)
        : 0.0;
    final double proteinRatio = targets.proteinTargetG > 0
        ? (consumedProtein / targets.proteinTargetG).clamp(0.0, 1.0)
        : 0.0;
    final double carbsRatio = targets.carbsTargetG > 0
        ? (consumedCarbs / targets.carbsTargetG).clamp(0.0, 1.0)
        : 0.0;
    final double fatRatio = targets.fatTargetG > 0
        ? (consumedFat / targets.fatTargetG).clamp(0.0, 1.0)
        : 0.0;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(AppIcons.calories, size: 19, color: c.calories),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Objetivos del Día',
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    targets.netWorkoutKcal > 0
                        ? 'Meta: $effectiveGoalKcal kcal (+${targets.netWorkoutKcal} entreno)'
                        : 'Meta: $effectiveGoalKcal kcal',
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.text2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (compact) ...<Widget>[
                Text(
                  '${remainingKcal.abs()} kcal',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                Text(
                  remainingKcal >= 0
                      ? 'disponibles · ${consumedKcal.round()} consumidas'
                      : 'por encima · ${consumedKcal.round()} consumidas',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    color: c.text2,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: kcalRatio,
                  minHeight: 7,
                  backgroundColor: c.bg3,
                  valueColor: AlwaysStoppedAnimation<Color>(c.calories),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
                _MacroLinearRow(
                  label: 'Proteína',
                  currentG: consumedProtein,
                  targetG: targets.proteinTargetG,
                  ratio: proteinRatio,
                  color: c.protein,
                ),
                const SizedBox(height: 6),
                _MacroLinearRow(
                  label: 'Carbos',
                  currentG: consumedCarbs,
                  targetG: targets.carbsTargetG,
                  ratio: carbsRatio,
                  color: c.carbs,
                ),
                const SizedBox(height: 6),
                _MacroLinearRow(
                  label: 'Grasas',
                  currentG: consumedFat,
                  targetG: targets.fatTargetG,
                  ratio: fatRatio,
                  color: c.fat,
                ),
              ] else ...<Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: CircularProgressIndicator(
                              value: kcalRatio,
                              strokeWidth: 9,
                              strokeCap:
                                  c.isFlat ? StrokeCap.butt : StrokeCap.round,
                              backgroundColor: c.bg3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(c.calories),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  '${remainingKcal.abs()}',
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: c.text,
                                  ),
                                ),
                                Text(
                                  remainingKcal >= 0 ? 'restan' : 'extra',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: c.text2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _MacroLinearRow(
                            label: 'Proteína',
                            currentG: consumedProtein,
                            targetG: targets.proteinTargetG,
                            ratio: proteinRatio,
                            color: c.protein,
                          ),
                          const SizedBox(height: 8),
                          _MacroLinearRow(
                            label: 'Carbohidratos',
                            currentG: consumedCarbs,
                            targetG: targets.carbsTargetG,
                            ratio: carbsRatio,
                            color: c.carbs,
                          ),
                          const SizedBox(height: 8),
                          _MacroLinearRow(
                            label: 'Grasas saludables',
                            currentG: consumedFat,
                            targetG: targets.fatTargetG,
                            ratio: fatRatio,
                            color: c.fat,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (compact) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/comer'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(AppIcons.comer, size: 16),
                label: const Text('Registrar comida'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRepeatYesterday,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(AppIcons.repeat, size: 15),
                label: const Text('Repetir ayer'),
              ),
            ),
          ] else
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.go('/comer'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(AppIcons.comer, size: 16),
                    label: const Text('Registrar comida'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: onRepeatYesterday,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(AppIcons.repeat, size: 15),
                    label: const Text('Repetir ayer'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. WIDGET HIDRATACIÓN INTELIGENTE — 2×2 / 4×2
// ============================================================================
class HoyHydrationBentoCard extends StatelessWidget {
  const HoyHydrationBentoCard({
    super.key,
    required this.size,
    required this.totalWaterMl,
    required this.goalMl,
    required this.glassesCount,
    required this.canUndo,
    required this.onAdd250,
    required this.onAdd500,
    required this.onUndoLast,
  });

  final HoyWidgetSize size;
  final int totalWaterMl;
  final int goalMl;
  final int glassesCount;
  final bool canUndo;
  final VoidCallback onAdd250;
  final VoidCallback onAdd500;
  final VoidCallback onUndoLast;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool compact = size.isHalfWidth;
    final double ratio =
        goalMl > 0 ? (totalWaterMl / goalMl).clamp(0.0, 1.0) : 0.0;
    final int pct = (ratio * 100).round();

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(AppIcons.water, size: 19, color: c.water),
                      const SizedBox(width: 6),
                      Text(
                        'Hidratación',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (canUndo)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onUndoLast,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              AppIcons.undo,
                              size: 16,
                              color: c.text2,
                            ),
                          ),
                        ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: c.water,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$totalWaterMl ml',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: compact ? 22 : 24,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                compact
                    ? 'Meta: $goalMl ml'
                    : 'Meta diaria: $goalMl ml · $glassesCount tomas registradas hoy',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  color: c.text2,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(c.water),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onAdd250,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text(
                    '+250 ml',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: onAdd500,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text(
                    '+500 ml',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. WIDGET PESO Y COMPOSICIÓN EMA — 2×2 / 4×2 (CON MINI CURVA EN 4×2)
// ============================================================================
class HoyBodyBentoCard extends StatelessWidget {
  const HoyBodyBentoCard({
    super.key,
    required this.size,
    required this.latestMeasurement,
    required this.recentMeasurements,
    required this.targetWeightKg,
  });

  final HoyWidgetSize size;
  final BodyMeasurement? latestMeasurement;
  final List<BodyMeasurement> recentMeasurements;
  final double targetWeightKg;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final bool compact = size.isHalfWidth;
    final BodyMeasurement? m = latestMeasurement;

    final String fatLine;
    if (m?.validatedBodyFatPercentage != null) {
      fatLine =
          'Grasa Navy: ${m!.validatedBodyFatPercentage!.toStringAsFixed(1)}%';
    } else if (m?.bodyFatPercentage != null) {
      fatLine = 'Grasa BIA: ${m!.bodyFatPercentage!.toStringAsFixed(1)}%';
    } else {
      fatLine = 'Meta: ${targetWeightKg.toStringAsFixed(1)} kg';
    }

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.cuerpo, size: 19, color: c.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Peso y EMA',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!compact && recentMeasurements.length >= 2)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: _buildWeightTexts(c, m, fatLine),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      height: 54,
                      child: CustomPaint(
                        painter: _MiniWeightSparklinePainter(
                          values: recentMeasurements
                              .map((e) => e.trendWeightKg)
                              .toList(),
                          color: c.accent,
                          isFlat: c.isFlat,
                        ),
                      ),
                    ),
                  ],
                )
              else
                _buildWeightTexts(c, m, fatLine),
              if (m != null && m.isWaterRetentionSpike) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Retención hídrica temporal detectada',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.water,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => context.go('/cuerpo'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(AppIcons.bascula, size: 16),
              label: const Text(
                'Pesarme',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTexts(ScColors c, BodyMeasurement? m, String fatLine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          m != null ? '${m.weightKg.toStringAsFixed(1)} kg' : 'Sin pesaje',
          softWrap: true,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          m != null
              ? 'Tendencia EMA: ${m.trendWeightKg.toStringAsFixed(1)} kg'
              : 'Conecta tu Mi Scale 2 o registra manual',
          softWrap: true,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11.5,
            color: c.text2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          fatLine,
          softWrap: true,
          style: TextStyle(
            fontFamily: ScFonts.ui,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: c.accent,
          ),
        ),
      ],
    );
  }
}

class _MiniWeightSparklinePainter extends CustomPainter {
  const _MiniWeightSparklinePainter({
    required this.values,
    required this.color,
    required this.isFlat,
  });

  final List<double> values;
  final Color color;
  final bool isFlat;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final double minV = values.reduce(math.min);
    final double maxV = values.reduce(math.max);
    final double span = (maxV - minV).abs() < 0.2 ? 1.0 : (maxV - minV);

    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = (i / (values.length - 1)) * size.width;
      final double normY = (values[i] - minV) / span;
      final double y = size.height - 6 - (normY * (size.height - 12));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isFlat ? 2.2 : 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniWeightSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.isFlat != isFlat;
  }
}

// ============================================================================
// 5. WIDGET PASOS NEAT — 2×2 / 4×2
// ============================================================================
class HoyStepsBentoCard extends StatelessWidget {
  const HoyStepsBentoCard({
    super.key,
    required this.size,
    required this.steps,
    required this.goalSteps,
    required this.onQuickAdd1000,
    required this.onOpenSheet,
  });

  final HoyWidgetSize size;
  final int steps;
  final int goalSteps;
  final VoidCallback onQuickAdd1000;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio =
        goalSteps > 0 ? (steps / goalSteps).clamp(0.0, 1.0) : 0.0;
    final int activeKcal = (steps * 0.04).round();

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.steps, size: 19, color: c.steps),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pasos NEAT',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$steps',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Meta: $goalSteps · ~$activeKcal kcal activas',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  color: c.text2,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(c.steps),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onQuickAdd1000,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text(
                    '+1,000',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenSheet,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text(
                    'Ajustar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. WIDGET SUEÑO Y DESCANSO REPARADOR — 2×2 / 4×2
// ============================================================================
class HoySleepBentoCard extends StatelessWidget {
  const HoySleepBentoCard({
    super.key,
    required this.size,
    required this.sleepHours,
    required this.goalHours,
    required this.hasSleepBonus,
    required this.onOpenSheet,
  });

  final HoyWidgetSize size;
  final double sleepHours;
  final double goalHours;
  final bool hasSleepBonus;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final double ratio =
        goalHours > 0 ? (sleepHours / goalHours).clamp(0.0, 1.0) : 0.0;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.sueno, size: 19, color: c.fasting),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sueño',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)} h' : '-- h',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasSleepBonus
                    ? 'Sueño reparador · Bono x1.5 🪙 activo'
                    : 'Meta: ${goalHours.toStringAsFixed(1)} h de descanso',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  fontWeight:
                      hasSleepBonus ? FontWeight.w700 : FontWeight.w500,
                  color: hasSleepBonus ? c.accent : c.text2,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: c.bg3,
                valueColor: AlwaysStoppedAnimation<Color>(c.fasting),
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onOpenSheet,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(AppIcons.sueno, size: 15),
              label: const Text(
                'Registrar sueño',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. WIDGET ENTRENAMIENTO RPE EN 5 SEGUNDOS — 2×2 / 4×2
// ============================================================================
class HoyWorkoutBentoCard extends ConsumerWidget {
  const HoyWorkoutBentoCard({
    super.key,
    required this.size,
    required this.workoutsToday,
    required this.profile,
  });

  final HoyWidgetSize size;
  final List<WorkoutBlock> workoutsToday;
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final int totalNetKcal = workoutsToday.fold<int>(
      0,
      (int sum, WorkoutBlock w) => sum + w.netCaloriesBurned,
    );
    final int totalMinutes = workoutsToday.fold<int>(
      0,
      (int sum, WorkoutBlock w) => sum + w.durationMinutes,
    );

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.pesa, size: 19, color: c.calories),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Entrenamiento',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                workoutsToday.isNotEmpty
                    ? '$totalNetKcal kcal'
                    : 'Sin sesión hoy',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: workoutsToday.isNotEmpty ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                workoutsToday.isNotEmpty
                    ? '${workoutsToday.length} bloque(s) · $totalMinutes min efectivos'
                    : 'Registra fuerza, cardio o deporte por RPE',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  color: c.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => QuickRpeWorkoutSheet.show(
                context: context,
                ref: ref,
                profile: profile,
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(AppIcons.bolt, size: 16),
              label: const Text(
                'Entreno 5s',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 8. WIDGET AYUNO INTERMITENTE Y FASE METABÓLICA — 2×2 / 4×2
// ============================================================================
class HoyFastingBentoCard extends StatelessWidget {
  const HoyFastingBentoCard({
    super.key,
    required this.size,
    required this.activeFast,
  });

  final HoyWidgetSize size;
  final FastingSession? activeFast;

  static String _phaseLabel(double hours) {
    if (hours >= 16) return 'Autofagia profunda 🔥';
    if (hours >= 12) return 'Cetosis activa ✨';
    if (hours >= 4) return 'Quema glucógeno';
    return 'Fase digestiva';
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final FastingSession? fast = activeFast;
    final bool isFasting = fast != null;

    final int elapsedMinutes = isFasting
        ? DateTime.now().difference(fast.startedAt).inMinutes.clamp(0, 99999)
        : 0;
    final int h = elapsedMinutes ~/ 60;
    final int m = elapsedMinutes % 60;
    final double elapsedHours = elapsedMinutes / 60.0;
    final int targetH = fast?.targetHours ?? 16;
    final double ratio =
        isFasting && targetH > 0 ? (elapsedHours / targetH).clamp(0.0, 1.0) : 0.0;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(AppIcons.fasting, size: 19, color: c.fasting),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ayuno',
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isFasting ? '${h}h ${m.toString().padLeft(2, '0')}m' : '16:8 libre',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: isFasting ? 22 : 19,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isFasting
                    ? '${_phaseLabel(elapsedHours)} · Meta ${targetH}h'
                    : 'Ventana abierta · Descanso digestivo listo',
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11.5,
                  color: isFasting && elapsedHours >= 12 ? c.fasting : c.text2,
                  fontWeight: isFasting && elapsedHours >= 12
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              if (isFasting) ...<Widget>[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
                  backgroundColor: c.bg3,
                  valueColor: AlwaysStoppedAnimation<Color>(c.fasting),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/ayuno'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: Icon(
                isFasting ? AppIcons.timer : AppIcons.fasting,
                size: 16,
              ),
              label: Text(
                isFasting ? 'Ver progreso' : 'Iniciar ayuno',
                style:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENTES AUXILIARES COMPARTIDOS Y HOJA DE PASOS + SUEÑO
// ============================================================================
class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.isFlat ? c.bg3 : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: c.isFlat ? c.line2 : color.withValues(alpha: 0.4),
          width: c.isFlat ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: c.isFlat ? c.text : color),
          const SizedBox(width: 5),
          Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.isFlat ? c.text : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroLinearRow extends StatelessWidget {
  const _MacroLinearRow({
    required this.label,
    required this.currentG,
    required this.targetG,
    required this.ratio,
    required this.color,
  });

  final String label;
  final double currentG;
  final double targetG;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${currentG.toInt()}/${targetG.toInt()} g',
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 5,
          backgroundColor: c.bg3,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

/// Hoja rápida (< 5s) para ajustar Pasos NEAT, Horas de Sueño y sincronizar Health Connect.
class HoyStepsSleepSheet extends ConsumerStatefulWidget {
  const HoyStepsSleepSheet({
    super.key,
    required this.dateKey,
    required this.profile,
    this.currentSummary,
  });

  final String dateKey;
  final UserProfile profile;
  final DailySummary? currentSummary;

  static Future<void> show({
    required BuildContext context,
    required String dateKey,
    required UserProfile profile,
    DailySummary? currentSummary,
  }) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => HoyStepsSleepSheet(
        dateKey: dateKey,
        profile: profile,
        currentSummary: currentSummary,
      ),
    );
  }

  @override
  ConsumerState<HoyStepsSleepSheet> createState() => _HoyStepsSleepSheetState();
}

class _HoyStepsSleepSheetState extends ConsumerState<HoyStepsSleepSheet> {
  late int _steps;
  late double _sleepHours;
  late bool _isRestorativeSleep;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _steps = widget.currentSummary?.stepsCount ?? 0;
    final int currentMin = widget.currentSummary?.sleepDurationMinutes ?? 0;
    _sleepHours = currentMin > 0 ? (currentMin / 60.0).clamp(3.0, 12.0) : 7.5;
    final int deepRem = (widget.currentSummary?.sleepDeepMinutes ?? 0) +
        (widget.currentSummary?.sleepRemMinutes ?? 0);
    _isRestorativeSleep = deepRem >= 90 || _sleepHours >= 7.5;
  }

  Future<void> _syncFromHealthConnect() async {
    setState(() => _isSyncing = true);
    final hc = ref.read(healthConnectServiceProvider);
    final bool hasPerms = await hc.checkPermissions();
    if (!hasPerms) {
      await hc.requestPermissions();
    }

    final DateTime date = DateTime.tryParse(widget.dateKey) ?? DateTime.now();
    final int hcSteps = await hc.readStepsForDate(date);
    final HealthSleepSummary? hcSleep = await hc.readSleepForDate(date);

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (hcSteps > 0) _steps = hcSteps;
      if (hcSleep != null && hcSleep.totalDurationHours > 0) {
        _sleepHours = hcSleep.totalDurationHours.clamp(3.0, 12.0);
        _isRestorativeSleep = hcSleep.coinsMultiplier > 1.0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hcSteps > 0 || (hcSleep != null && hcSleep.totalDurationHours > 0)
              ? 'Datos sincronizados desde Health Connect'
              : 'Health Connect sin registros nuevos hoy; puedes ajustar aquí manualmente.',
        ),
      ),
    );
  }

  Future<void> _save() async {
    unawaited(HapticFeedback.lightImpact());
    final int totalSleepMin = (_sleepHours * 60).round();
    final int deepMin = _isRestorativeSleep ? 55 : 30;
    final int remMin = _isRestorativeSleep ? 45 : 25;
    final int activeKcal = (_steps * 0.04).round();

    await ref.read(healthSyncDaoProvider).upsertDailySummary(
          DailySummariesCompanion(
            dateKey: drift.Value(widget.dateKey),
            stepsCount: drift.Value(_steps),
            activeCaloriesFromSteps: drift.Value(activeKcal),
            sleepDurationMinutes: drift.Value(totalSleepMin),
            sleepDeepMinutes: drift.Value(deepMin),
            sleepRemMinutes: drift.Value(remMin),
          ),
        );

    if (_isRestorativeSleep || _sleepHours >= 7.5) {
      await ref.read(petDaoProvider).grantDailyReward(
            dateKey: widget.dateKey,
            actionType: 'restorative_sleep',
            baseAmount: 15,
            sleepMultiplier: 1.5,
          );
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Guardado: $_steps pasos y ${_sleepHours.toStringAsFixed(1)} h de sueño ✨',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Pasos NEAT y Sueño',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isSyncing ? null : _syncFromHealthConnect,
                icon: Icon(AppIcons.refresh, size: 16, color: c.accent),
                label:
                    Text(_isSyncing ? 'Sincronizando...' : 'Health Connect'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Pasos del día',
                style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
              ),
              Text(
                '$_steps / ${widget.profile.dailyStepsGoal}',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.steps,
                ),
              ),
            ],
          ),
          Slider(
            value: _steps.clamp(0, 25000).toDouble(),
            min: 0,
            max: 25000,
            divisions: 50,
            activeColor: c.steps,
            onChanged: (double v) => setState(() => _steps = v.round()),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChipPill(
                label: '+1,000 pasos',
                onTap: () =>
                    setState(() => _steps = (_steps + 1000).clamp(0, 50000)),
              ),
              ChipPill(
                label: '+2,500 pasos',
                onTap: () =>
                    setState(() => _steps = (_steps + 2500).clamp(0, 50000)),
              ),
              ChipPill(
                label: 'Meta (${widget.profile.dailyStepsGoal})',
                onTap: () =>
                    setState(() => _steps = widget.profile.dailyStepsGoal),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Horas de sueño anoche',
                style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
              ),
              Text(
                '${_sleepHours.toStringAsFixed(1)} h',
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c.fasting,
                ),
              ),
            ],
          ),
          Slider(
            value: _sleepHours,
            min: 3.0,
            max: 12.0,
            divisions: 18,
            activeColor: c.fasting,
            onChanged: (double v) => setState(() {
              _sleepHours = v;
              if (v >= 7.5) _isRestorativeSleep = true;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Sueño profundo / REM reparador',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            subtitle: Text(
              'Activa el multiplicador x1.5 🪙 de Nibi en tus hábitos de hoy',
              style: TextStyle(fontSize: 11.5, color: c.text2),
            ),
            value: _isRestorativeSleep,
            activeThumbColor: c.accent,
            onChanged: (bool v) => setState(() => _isRestorativeSleep = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Guardar Resumen Diario'),
            ),
          ),
        ],
      ),
    );
  }
}

