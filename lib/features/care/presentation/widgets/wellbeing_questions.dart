import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../domain/wellbeing_index.dart';

/// Las cinco frases del OMS-5 con sus seis respuestas.
class WellbeingQuestions extends StatelessWidget {
  const WellbeingQuestions({super.key, required this.answers, required this.onChanged});

  /// Una respuesta 0–5 por frase, `null` si aún no se respondió.
  final List<int?> answers;
  final void Function(int question, int answer) onChanged;

  static List<String> questions(AppLocalizations l10n) => <String>[
    l10n.wellbeingQ1,
    l10n.wellbeingQ2,
    l10n.wellbeingQ3,
    l10n.wellbeingQ4,
    l10n.wellbeingQ5,
  ];

  static List<String> options(AppLocalizations l10n) => <String>[
    l10n.wellbeingA0,
    l10n.wellbeingA1,
    l10n.wellbeingA2,
    l10n.wellbeingA3,
    l10n.wellbeingA4,
    l10n.wellbeingA5,
  ];

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final List<String> qs = questions(l10n);
    final List<String> opts = options(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int q = 0; q < WellbeingIndex.questionCount; q++) ...<Widget>[
          Text(qs[q], style: context.text.titleSmall?.copyWith(color: c.text)),
          const SizedBox(height: ScSpace.xs),
          Wrap(
            spacing: ScSpace.xs,
            runSpacing: ScSpace.xs,
            children: <Widget>[
              for (int a = 0; a <= WellbeingIndex.maxAnswer; a++)
                ChoiceChip(
                  label: Text(opts[a]),
                  selected: answers[q] == a,
                  onSelected: (_) => onChanged(q, a),
                ),
            ],
          ),
          const SizedBox(height: ScSpace.m),
        ],
      ],
    );
  }
}
