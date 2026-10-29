import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/smart_meal_suggester.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../profile_goals/application/profile_queries.dart';
import '../../../profile_goals/application/profile_service.dart';

/// Hoja modal para seleccionar el estilo de alimentación y el presupuesto semanal.
class DietArchetypePickerSheet extends ConsumerStatefulWidget {
  const DietArchetypePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return mostrarHojaMenu<void>(context, builder: (_) => const DietArchetypePickerSheet());
  }

  @override
  ConsumerState<DietArchetypePickerSheet> createState() => _DietArchetypePickerSheetState();
}

class _DietArchetypePickerSheetState extends ConsumerState<DietArchetypePickerSheet> {
  late DietArchetype _selectedArchetype;

  @override
  void initState() {
    super.initState();
    final UserProfile? profile = ref.read(userProfileStreamProvider).value;
    _selectedArchetype = profile?.activeDietArchetype ?? DietArchetype.balanced;
  }

  Future<void> _selectArchetype(DietArchetype id) async {
    setState(() => _selectedArchetype = id);
    unawaited(HapticFeedback.selectionClick());
    await ref.read(profileServiceProvider).setDietArchetype(id);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.l10n.foodEstiloActivado(DietArchetypeInfo.getById(id).name)),
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
                    context.l10n.foodArquetiposDieteticos,
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
            context.l10n.foodSeleccionaTuEnfoqueNutricionalEl,
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2, height: 1.3),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: DietArchetypeInfo.archetypes.values.map((DietArchetypeInfo arch) {
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
                            ? (c.isFlat ? c.bg3 : c.accent.withValues(alpha: 0.12))
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
                              Flexible(
                                child: Text(
                                  arch.name,
                                  style: TextStyle(
                                    fontFamily: ScFonts.display,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? c.accent : c.text,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: c.accent, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            arch.tagline,
                            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12, color: c.text2),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              _MacroPill(
                                label: context.l10n.foodP(NumberFormats.fixed(arch.proteinPct, 0)),
                                color: c.protein,
                              ),
                              const SizedBox(width: 6),
                              _MacroPill(
                                label: context.l10n.foodC(NumberFormats.fixed(arch.carbsPct, 0)),
                                color: c.carbs,
                              ),
                              const SizedBox(width: 6),
                              _MacroPill(
                                label: context.l10n.foodG13(NumberFormats.fixed(arch.fatPct, 0)),
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
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
