import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/food_dao.dart';
import '../../../../core/database/daos/user_profile_dao.dart';
import '../../../../core/services/calorie_cycling_service.dart';
import '../../../../core/services/smart_meal_suggester.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/sheet.dart';

/// Tarjeta del "Banco Semanal de Calorías" para NutricionScreen.
class CalorieBankCard extends ConsumerWidget {
  const CalorieBankCard({
    super.key,
    required this.today,
    required this.baseDailyKcal,
  });

  final DateTime today;
  final int baseDailyKcal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final CalorieCyclingService service = ref.watch(calorieCyclingServiceProvider);
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;

    final CalorieCyclingMode mode = profile?.calorieCyclingScheduleJson != null &&
            profile!.calorieCyclingScheduleJson.contains('weekendBuffer')
        ? CalorieCyclingMode.weekendBuffer
        : CalorieCyclingMode.flat;

    // Calcular consumo de la semana
    final WeeklyCalorieBank bank = service.computeWeeklyBank(
      baseDailyKcal: baseDailyKcal,
      today: today,
      caloriesLoggedByDateKey: <String, int>{},
      mode: mode,
    );

    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_rounded,
                color: c.accent,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Banco Semanal de Calorías',
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.isFlat ? c.line2 : c.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${bank.remainingDaysInWeek} d restantes',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.isFlat ? c.text : c.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bank.hasBankSavings
                ? 'Tienes +${bank.netBalanceKcal} kcal acumuladas en reserva. Una comida más abundante el fin de semana encaja perfectamente en tu balance neto semanal.'
                : 'La energía semanal se autorregula. Lo que importa para tu composición corporal es el balance acumulado de 7 días, no un único día aislado.',
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _BankStat(
                  label: 'Objetivo Acumulado',
                  value: '${bank.accumulatedTargetKcal} kcal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BankStat(
                  label: 'Arquetipo Activo',
                  value: DietArchetypeInfo.getById(
                    profile?.activeDietArchetype,
                  ).name,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BankStat extends StatelessWidget {
  const _BankStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.3 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 10.5,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja modal para seleccionar el estilo de alimentación y el presupuesto semanal.
class DietArchetypePickerSheet extends ConsumerStatefulWidget {
  const DietArchetypePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => const DietArchetypePickerSheet(),
    );
  }

  @override
  ConsumerState<DietArchetypePickerSheet> createState() =>
      _DietArchetypePickerSheetState();
}

class _DietArchetypePickerSheetState
    extends ConsumerState<DietArchetypePickerSheet> {
  late String _selectedArchetype;

  @override
  void initState() {
    super.initState();
    final UserProfile? profile = ref.read(userProfileStreamProvider).value;
    _selectedArchetype = profile?.activeDietArchetype ?? 'balanced';
  }

  Future<void> _selectArchetype(String id) async {
    setState(() => _selectedArchetype = id);
    unawaited(HapticFeedback.selectionClick());
    await ref.read(userProfileDaoProvider).updateDietArchetype(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Estilo ${DietArchetypeInfo.getById(id).name} activado!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.style_rounded, color: c.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Arquetipos Dietéticos',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona tu enfoque nutricional. El motor adaptará las porciones sugeridas y la distribución de macronutrientes.',
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: DietArchetypeInfo.archetypes.values
                  .map((DietArchetypeInfo arch) {
                final bool isSelected = arch.id == _selectedArchetype;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _selectArchetype(arch.id),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (c.isFlat
                                ? c.bg3
                                : c.accent.withValues(alpha: 0.12))
                            : c.bg2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (c.isFlat ? c.text : c.accent)
                              : (c.isFlat ? c.line2 : c.line),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                arch.name,
                                style: TextStyle(
                                  fontFamily: ScFonts.display,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? c.accent : c.text,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: c.accent,
                                  size: 18,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            arch.tagline,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 12,
                              color: c.text2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              _MacroPill(
                                label:
                                    'P: ${arch.proteinPct.toStringAsFixed(0)}%',
                                color: c.protein,
                              ),
                              const SizedBox(width: 6),
                              _MacroPill(
                                label: 'C: ${arch.carbsPct.toStringAsFixed(0)}%',
                                color: c.carbs,
                              ),
                              const SizedBox(width: 6),
                              _MacroPill(
                                label: 'G: ${arch.fatPct.toStringAsFixed(0)}%',
                                color: c.fat,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: ScFonts.ui,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Hoja modal del menú diario sugerido con porciones exactas.
class SmartMealMenuSheet extends ConsumerStatefulWidget {
  const SmartMealMenuSheet({
    super.key,
    required this.targetDateKey,
  });

  final String targetDateKey;

  static Future<void> show(
    BuildContext context, {
    required String targetDateKey,
  }) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => SmartMealMenuSheet(targetDateKey: targetDateKey),
    );
  }

  @override
  ConsumerState<SmartMealMenuSheet> createState() => _SmartMealMenuSheetState();
}

class _SmartMealMenuSheetState extends ConsumerState<SmartMealMenuSheet> {
  SuggestedDailyMenu? _menu;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_generate());
  }

  Future<void> _generate() async {
    setState(() => _isLoading = true);
    final UserProfile? profile = ref.read(userProfileStreamProvider).value;
    final FoodDao foodDao = ref.read(foodDaoProvider);

    if (profile == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final SuggestedDailyMenu m = await ref
        .read(smartMealSuggesterProvider)
        .generateMenu(profile: profile, foodDao: foodDao);

    if (mounted) {
      setState(() {
        _menu = m;
        _isLoading = false;
      });
    }
  }

  Future<void> _logMealSlot(
    String mealSlot,
    List<SuggestedMealItem> items,
  ) async {
    final FoodDao foodDao = ref.read(foodDaoProvider);
    unawaited(HapticFeedback.mediumImpact());

    for (final SuggestedMealItem item in items) {
      await foodDao.logFoodItemPortion(
        food: item.food,
        grams: item.grams,
        dateKey: widget.targetDateKey,
        mealType: mealSlot,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Comida registrada en ${mealSlot.toUpperCase()} con porciones exactas! 🍽️',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: c.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Menú Sugerido Inteligente',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_menu != null)
            Text(
              'Estilo ${_menu!.archetype.name} • ${_menu!.targetKcal} kcal meta diaria calculada al gramo.',
              style: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 12,
                color: c.text2,
              ),
            ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _menu == null
                    ? const Center(child: Text('No hay datos disponibles.'))
                    : ListView(
                        children: _menu!.meals.entries.map((MapEntry<String, List<SuggestedMealItem>> entry) {
                          final String slot = entry.key;
                          final List<SuggestedMealItem> items = entry.value;

                          String slotTitle;
                          switch (slot) {
                            case 'breakfast':
                              slotTitle = 'Desayuno';
                              break;
                            case 'lunch':
                              slotTitle = 'Almuerzo';
                              break;
                            case 'dinner':
                              slotTitle = 'Cena';
                              break;
                            default:
                              slotTitle = slot;
                          }

                          final double slotKcal = items.fold(0.0, (double sum, SuggestedMealItem i) => sum + i.kcal);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: c.bg3,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: c.isFlat ? c.line2 : c.line,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(
                                      '$slotTitle (${slotKcal.round()} kcal)',
                                      style: TextStyle(
                                        fontFamily: ScFonts.display,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: c.text,
                                      ),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _logMealSlot(slot, items),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('Registrar'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...items.map((SuggestedMealItem item) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 15,
                                          color: c.accent,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${item.food.name} • ${item.grams.round()}g',
                                            style: TextStyle(
                                              fontFamily: ScFonts.ui,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: c.text,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${item.kcal.round()} kcal',
                                          style: TextStyle(
                                            fontFamily: ScFonts.ui,
                                            fontSize: 12,
                                            color: c.text2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Hoja modal del "Oráculo de Nutrientes" para cerrar déficits al final del día.
class NutrientOracleSheet extends ConsumerWidget {
  const NutrientOracleSheet({
    super.key,
    required this.remainingKcal,
    required this.remainingProteinG,
    required this.remainingCarbsG,
    required this.remainingFatG,
    required this.targetDateKey,
    required this.mealType,
  });

  final double remainingKcal;
  final double remainingProteinG;
  final double remainingCarbsG;
  final double remainingFatG;
  final String targetDateKey;
  final String mealType;

  static Future<void> show(
    BuildContext context, {
    required double remainingKcal,
    required double remainingProteinG,
    required double remainingCarbsG,
    required double remainingFatG,
    required String targetDateKey,
    String mealType = 'dinner',
  }) {
    return mostrarHojaMenu<void>(
      context,
      builder: (_) => NutrientOracleSheet(
        remainingKcal: remainingKcal,
        remainingProteinG: remainingProteinG,
        remainingCarbsG: remainingCarbsG,
        remainingFatG: remainingFatG,
        targetDateKey: targetDateKey,
        mealType: mealType,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final FoodDao foodDao = ref.watch(foodDaoProvider);
    final NutrientOracle oracle = ref.watch(nutrientOracleProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.lightbulb_rounded, color: c.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Oráculo de Nutrientes',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Te faltan ${remainingKcal.round()} kcal (P: ${remainingProteinG.round()}g | C: ${remainingCarbsG.round()}g | G: ${remainingFatG.round()}g). Aquí tienes opciones exactas de tu catálogo para cerrar tus metas:',
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12,
              color: c.text2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<SuggestedMealItem>>(
              future: oracle.recommendToCloseGap(
                remainingKcal: remainingKcal,
                remainingProteinG: remainingProteinG,
                remainingCarbsG: remainingCarbsG,
                remainingFatG: remainingFatG,
                foodDao: foodDao,
              ),
              builder: (BuildContext ctx,
                  AsyncSnapshot<List<SuggestedMealItem>> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<SuggestedMealItem> recs =
                    snap.data ?? <SuggestedMealItem>[];
                if (recs.isEmpty) {
                  return Center(
                    child: Text(
                      '¡Tus metas están prácticamente cubiertas o no hay alimentos compatibles!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.text2),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: recs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext ctx, int i) {
                    final SuggestedMealItem item = recs[i];
                    return HealthCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.isFlat ? c.line2 : c.soft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.restaurant_rounded,
                              size: 18,
                              color: c.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.food.name,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Servir ${item.grams.round()}g • ${item.kcal.round()} kcal',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    color: c.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'P: ${item.proteinG}g | C: ${item.carbsG}g | G: ${item.fatG}g',
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11,
                                    color: c.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              unawaited(HapticFeedback.mediumImpact());
                              await foodDao.logFoodItemPortion(
                                food: item.food,
                                grams: item.grams,
                                dateKey: targetDateKey,
                                mealType: mealType,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '¡${item.grams.round()}g de ${item.food.name} registrados!',
                                    ),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('Comer'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
