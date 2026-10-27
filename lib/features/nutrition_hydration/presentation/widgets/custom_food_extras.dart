import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';

/// Bloque plegable con minerales, código de barras y Nutri-Score de un alimento propio.
class CustomFoodExtras extends StatelessWidget {
  const CustomFoodExtras({
    super.key,
    required this.sodiumController,
    required this.potassiumController,
    required this.magnesiumController,
    required this.barcodeController,
    required this.nutriScore,
    required this.onNutriScore,
    required this.expanded,
    required this.onToggle,
  });

  final TextEditingController sodiumController;
  final TextEditingController potassiumController;
  final TextEditingController magnesiumController;
  final TextEditingController barcodeController;
  final String? nutriScore;
  final ValueChanged<String?> onNutriScore;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 3. Sección expandible: Electrolitos, Código de Barras y Nutri-Score
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onToggle();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: c.bg3,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: c.isFlat ? c.line2 : c.line,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(AppIcons.bolt, size: 18, color: c.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.foodElectrolitosEanYNutriScore,
                    softWrap: true,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: c.text2,
                ),
              ],
            ),
          ),
        ),

        if (expanded) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: CustomFoodNumberField(
                  controller: sodiumController,
                  label: context.l10n.foodSodioMg100g,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomFoodNumberField(
                  controller: potassiumController,
                  label: context.l10n.foodPotasioMg100g,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: CustomFoodNumberField(
                  controller: magnesiumController,
                  label: context.l10n.foodMagnesioMg100g,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: barcodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.foodCodigoEanOpcional,
                    filled: true,
                    fillColor: c.bg3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.foodNutriScoreSiApareceEn,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <String>['A', 'B', 'C', 'D', 'E']
                .map((String grade) {
              final bool active = nutriScore == grade;
              return ChoiceChip(
                label: Text(context.l10n.foodGrado((grade).toString())),
                selected: active,
                onSelected: (bool v) {
                  unawaited(HapticFeedback.selectionClick());
                  onNutriScore(v ? grade : null);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Campo numérico (acepta coma o punto decimal) de la ficha de alimento propio.
class CustomFoodNumberField extends StatelessWidget {
  const CustomFoodNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: c.bg3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
