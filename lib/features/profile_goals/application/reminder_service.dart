import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/reminders_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/domain/enums.dart';
import '../../../core/platform/native_call.dart';
import '../../../core/platform/notification_gateway.dart';

/// Recordatorios de hábitos (docs/07 §1.2): la tabla `reminders` es la fuente de
/// verdad y cada cambio reprograma las alarmas locales del sistema.
class ReminderService {
  ReminderService(this._remindersDao, this._profileDao, this._notifications);

  final RemindersDao _remindersDao;
  final UserProfileDao _profileDao;
  final NotificationGateway _notifications;

  /// Textos en positivo: invitan, nunca reprochan (ADR-08).
  static ({String title, String body}) copyFor(ReminderType type) => switch (type) {
    ReminderType.morningWeighIn => (
      title: 'Pesaje matutino',
      body: 'En ayunas y descalzo: 15 segundos para tu Peso Tendencia.',
    ),
    ReminderType.hydration => (
      title: 'Un vaso de agua',
      body: 'Tu cuerpo lo agradece. Regístralo con un toque.',
    ),
    ReminderType.fastingOpen => (
      title: 'Se abre tu ventana de comida',
      body: 'Empieza suave: proteína, verduras y buena hidratación.',
    ),
    ReminderType.fastingClose => (
      title: 'Cierra tu ventana de comida',
      body: 'Buen momento para la última comida del día.',
    ),
    ReminderType.tapeMeasure => (
      title: 'Validación con cinta métrica',
      body: 'Cintura y cuello (y cadera): menos de 15 segundos.',
    ),
    ReminderType.journal => (
      title: 'Un momento para ti',
      body: '¿Cómo te sentiste hoy? Unas palabras en tu diario.',
    ),
  };

  Future<void> seedDefaults() async {
    await _remindersDao.seedDefaultRemindersIfEmpty();
    await syncSchedules();
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await _remindersDao.toggleReminder(id, enabled);
    await syncSchedules();
  }

  Future<void> setTime(int id, int minutesOfDay) async {
    await _remindersDao.updateReminderTime(id, minutesOfDay);
    await syncSchedules();
  }

  /// Reprograma todos los recordatorios activos. Los de la ventana de ayuno se
  /// omiten si el usuario desactivó el módulo de ayuno (modos contextuales).
  Future<void> syncSchedules() async {
    final UserProfile? profile = await _profileDao.getProfile();
    final bool fastingEnabled = profile?.isFastingEnabled ?? true;
    final List<Reminder> reminders = await _remindersDao.getEnabledReminders();

    await bestEffort(
      () => _notifications.setReminders(<ScheduledReminder>[
        for (final Reminder r in reminders)
          if (fastingEnabled ||
              (r.reminderType != ReminderType.fastingOpen &&
                  r.reminderType != ReminderType.fastingClose))
            ScheduledReminder(
              id: r.id,
              title: copyFor(r.reminderType).title,
              body: copyFor(r.reminderType).body,
              minutesOfDay: r.timeOfDayMinutes,
              daysMask: r.daysOfWeekBitmask,
              intervalMinutes: r.intervalMinutes,
            ),
      ]),
      null,
    );
  }
}

final reminderServiceProvider = Provider<ReminderService>((Ref ref) {
  return ReminderService(
    ref.watch(remindersDaoProvider),
    ref.watch(userProfileDaoProvider),
    ref.watch(notificationGatewayProvider),
  );
});
