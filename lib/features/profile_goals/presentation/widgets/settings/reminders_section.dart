import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/domain/care_enums.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/platform/system_permissions.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/section_head.dart';
import '../../../../care/application/care_preferences_service.dart';
import '../../../../care/application/care_queries.dart';
import '../../../../today/application/movement_nudge_service.dart';
import '../../../application/profile_queries.dart';
import '../../../application/reminder_service.dart';

String formatReminderTime(int totalMinutes) {
  final int h = (totalMinutes ~/ 60).clamp(0, 23);
  final int m = (totalMinutes % 60).clamp(0, 59);
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String reminderTitle(AppLocalizations l10n, ReminderType type) {
  return switch (type) {
    ReminderType.morningWeighIn => l10n.settingsPesajeMatutinoEnAyunas,
    ReminderType.hydration => l10n.settingsPausaDeHidratacionActiva,
    ReminderType.fastingOpen => l10n.settingsAperturaDeVentanaAlimenticia,
    ReminderType.fastingClose => l10n.settingsCierreDeVentanaAlimenticia,
    ReminderType.journal => l10n.settingsReflexionNocturnaSinPantallas,
    ReminderType.tapeMeasure => l10n.settingsControlQuincenalUsNavy,
    ReminderType.windDown => l10n.settingsReminderWindDown,
    ReminderType.pelvicFloor => l10n.settingsReminderPelvicFloor,
    ReminderType.eyeRest => l10n.settingsReminderEyeRest,
  };
}

/// Recordatorios de apartados ocultos no se muestran (ni suenan).
bool _isReminderVisible(ReminderType type, Set<CareModule> modules) => switch (type) {
  ReminderType.pelvicFloor => modules.contains(CareModule.pelvicFloor),
  ReminderType.eyeRest => modules.contains(CareModule.activeBreaks),
  _ => true,
};

/// Recordatorios y pausas activas.
class RemindersSection extends ConsumerWidget {
  const RemindersSection({
    super.key,
    required this.reminders,
    required this.movementStatus,
    required this.onMovementChanged,
  });

  final List<Reminder> reminders;
  final MovementNudgeStatus movementStatus;
  final ValueChanged<MovementNudgeStatus> onMovementChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    final Set<CareModule> modules = ref.watch(careModulesProvider);
    final UserProfile? profile = ref.watch(userProfileStreamProvider).value;
    final int bedtime = profile?.targetBedtimeMinutes ?? 23 * 60;
    final List<Reminder> visible = reminders
        .where((Reminder r) => _isReminderVisible(r.reminderType, modules))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(
          title: context.l10n.settingsRecordatoriosDelSantuario,
          subtitle: context.l10n.settingsHorariosLocalesAjustablesParaTus,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bedtime_outlined),
                title: Text(context.l10n.settingsBedtime),
                subtitle: Text(context.l10n.settingsBedtimeHint),
                trailing: TextButton(
                  onPressed: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      confirmText: context.l10n.commonAccept,
                      errorInvalidText: context.l10n.commonInvalidTime,
                      initialTime: TimeOfDay(hour: bedtime ~/ 60, minute: bedtime % 60),
                    );
                    if (picked != null) {
                      await ref
                          .read(carePreferencesServiceProvider)
                          .setTargetBedtime(picked.hour * 60 + picked.minute);
                    }
                  },
                  child: Text(formatReminderTime(bedtime)),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.visibility_off_outlined),
                title: Text(context.l10n.settingsDiscreet),
                subtitle: Text(context.l10n.settingsDiscreetHint),
                value: profile?.discreetNotifications ?? true,
                onChanged: (bool v) =>
                    ref.read(carePreferencesServiceProvider).setDiscreetNotifications(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          child: visible.isEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.l10n.settingsActivaTus4RutinasSugeridas,
                        style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => ref.read(reminderServiceProvider).seedDefaults(),
                      icon: const Icon(AppIcons.alarm, size: 16),
                      label: Text(context.l10n.settingsActivar),
                    ),
                  ],
                )
              : Column(
                  children: <Widget>[
                    for (final Reminder rem in visible)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          reminderTitle(context.l10n, rem.reminderType),
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        subtitle: GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              confirmText: context.l10n.commonAccept,
                              // Corto: el aviso largo de Flutter ocupaba dos líneas y desbordaba el diálogo.
                              errorInvalidText: context.l10n.commonInvalidTime,
                              initialTime: TimeOfDay(
                                hour: rem.timeOfDayMinutes ~/ 60,
                                minute: rem.timeOfDayMinutes % 60,
                              ),
                            );
                            if (picked != null) {
                              await ref
                                  .read(reminderServiceProvider)
                                  .setTime(rem.id, picked.hour * 60 + picked.minute);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              context.l10n.settingsHorarioTocarParaCambiar(
                                formatReminderTime(rem.timeOfDayMinutes).toString(),
                              ),
                              style: TextStyle(fontSize: 11.5, color: c.accent),
                            ),
                          ),
                        ),
                        value: rem.isEnabled,
                        onChanged: (bool val) async {
                          // Un recordatorio sin permiso de notificaciones no se vería.
                          if (val) {
                            await ref
                                .read(systemPermissionsProvider)
                                .request(AppPermission.notifications);
                          }
                          await ref.read(reminderServiceProvider).setEnabled(rem.id, val);
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.directions_walk_rounded),
            title: Text(context.l10n.settingsPausasActivas),
            subtitle: Text(switch (movementStatus) {
              MovementNudgeStatus.enabled => context.l10n.settingsTeInvitaremosAMoverteTras,
              MovementNudgeStatus.needsHealthConnect =>
                context.l10n.settingsConcedeAHealthConnectLa,
              MovementNudgeStatus.unsupported =>
                context.l10n.settingsRequiereHealthConnectConLectura,
              MovementNudgeStatus.disabled => context.l10n.settingsUnaInvitacionAmableAEstirarte,
            }),
            value:
                movementStatus == MovementNudgeStatus.enabled ||
                movementStatus == MovementNudgeStatus.needsHealthConnect,
            onChanged: movementStatus == MovementNudgeStatus.unsupported
                ? null
                : (bool enabled) async {
                    if (enabled) {
                      await ref
                          .read(systemPermissionsProvider)
                          .request(AppPermission.notifications);
                    }
                    final MovementNudgeStatus next = await ref
                        .read(movementNudgeServiceProvider)
                        .setEnabled(enabled);
                    onMovementChanged(next);
                  },
          ),
        ),

        const SizedBox(height: 24),

        // ==========================================
      ],
    );
  }
}
