import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/care_enums.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_tokens.dart';
import '../../../shared/utils/current_date_provider.dart';
import '../../../shared/utils/date_formats.dart';
import '../../../shared/widgets/entrance.dart';
import '../../../shared/widgets/top_bar.dart';
import '../application/care_queries.dart';
import 'widgets/checkups_card.dart';
import 'widgets/guided_care_cards.dart';
import 'widgets/habits_card.dart';
import 'widgets/substances_card.dart';
import 'widgets/support_lines.dart';
import 'widgets/symptoms_card.dart';
import 'widgets/treatments_card.dart';
import 'widgets/vitals_card.dart';

/// Pestaña "Cuidado": lo que no es comida, cuerpo ni Nibi pero también es
/// cuidarse. Cada apartado se puede ocultar en Ajustes; los signos vitales solo
/// aparecen si la persona tiene el aparato.
class CuidadoScreen extends ConsumerWidget {
  const CuidadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final AppLocalizations l10n = context.l10n;
    final DateTime today = ref.watch(currentDateProvider);
    final String dateKey = ref.watch(currentDateKeyProvider);
    final Set<CareModule> modules = ref.watch(careModulesProvider);
    final Set<VitalKind> vitals = ref.watch(vitalDevicesProvider);
    final String formattedDate = DateFormats.weekdayDayMonth(today, l10n.localeName);

    int order = 0;
    Widget enter(Widget child) => Entrance(index: order++, child: child);

    final List<Widget> cards = <Widget>[
      if (modules.contains(CareModule.treatments)) TreatmentsCard(dateKey: dateKey),
      if (modules.contains(CareModule.habits)) HabitsCard(dateKey: dateKey),
      if (modules.contains(CareModule.pelvicFloor)) const PelvicFloorCard(),
      if (modules.contains(CareModule.activeBreaks)) const ActiveBreaksCard(),
      if (vitals.isNotEmpty) VitalsCard(kinds: vitals),
      if (modules.contains(CareModule.symptoms)) SymptomsCard(dateKey: dateKey),
      if (modules.contains(CareModule.checkups)) const CheckupsCard(),
      if (modules.contains(CareModule.substances)) const SubstancesCard(),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: ScSpace.bottomInset),
          children: <Widget>[
            TopBar(
              title: l10n.careTitle,
              subtitle: formattedDate[0].toUpperCase() + formattedDate.substring(1),
              large: true,
              trailing: TopBarAction(
                icon: Icons.tune_rounded,
                tooltip: l10n.careChooseModules,
                onPressed: () => unawaited(context.push('/ajustes')),
              ),
            ),
            if (cards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(ScSpace.gutter),
                child: Text(l10n.careEmptyAll, style: context.text.bodyMedium),
              ),
            for (final Widget card in cards) enter(card),
            const SizedBox(height: ScSpace.m),
            Center(
              child: TextButton.icon(
                onPressed: () => unawaited(SupportLines.show(context)),
                icon: const Icon(Icons.support_rounded, size: 18),
                label: Text(l10n.supportTitle),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => unawaited(context.push('/ajustes')),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(l10n.careChooseModules),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
