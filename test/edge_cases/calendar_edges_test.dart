import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/domain/streak_policy.dart';
import 'package:nb_selfcare/shared/utils/biometric_formulas.dart';
import 'package:nb_selfcare/shared/utils/date_time_extensions.dart';

/// Fechas límite. Estas pruebas tienen sentido en cualquier zona horaria y se
/// ejecutan también con `TZ=Europe/Madrid` (cambios de horario) y
/// `TZ=Pacific/Chatham` (desfase +13:45) en la verificación de la app.
void main() {
  group('Aritmética de calendario', () {
    test('el día anterior al de un cambio de horario es el día anterior', () {
      for (final (DateTime d, String expected) in <(DateTime, String)>[
        (DateTime(2026, 3, 30), '2026-03-29'), // tras el cambio de marzo (Europa)
        (DateTime(2026, 10, 26), '2026-10-25'), // tras el cambio de octubre (Europa)
        (DateTime(2026, 3, 9), '2026-03-08'), // EE. UU.
        (DateTime(2026, 1, 1), '2025-12-31'),
        (DateTime(2028, 3, 1), '2028-02-29'),
      ]) {
        expect(d.addDays(-1).dateKey, expected);
      }
      expect(DateTime(2026, 3, 28, 23, 30).addDays(1).dateKey, '2026-03-29');
      expect(DateTime(2027, 12, 31).addDays(1).dateKey, '2028-01-01');
    });

    test('días de calendario entre fechas con distinto desfase horario', () {
      expect(DateTime(2026, 3, 30, 0, 30).calendarDaysSince(DateTime(2026, 3, 29, 23, 50)), 1);
      expect(DateTime(2026, 10, 26, 0, 10).calendarDaysSince(DateTime(2026, 10, 25, 1)), 1);
      expect(DateTime(2028, 3, 1).calendarDaysSince(DateTime(2028, 2, 28)), 2);
      expect(DateTime(2026, 1, 1).calendarDaysSince(DateTime(2026, 1, 1, 23, 59)), 0);
    });

    test('una semana de lunes a domingo que cruza el año', () {
      final DateTime thursday = DateTime(2026, 12, 31);
      final DateTime monday = thursday.addDays(1 - thursday.weekday);
      expect(monday.dateKey, '2026-12-28');
      expect(monday.addDays(6).dateKey, '2027-01-03');
    });
  });

  group('Racha', () {
    test('días perdidos alrededor de un cambio de horario y de un 29 de febrero', () {
      expect(StreakPolicy.missedDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 1);
      expect(StreakPolicy.missedDaysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 1);
      expect(
        StreakPolicy.missedDaysBetween(DateTime(2026, 10, 25, 23), DateTime(2026, 10, 26, 0, 30)),
        0,
      );
    });
  });

  group('Edad', () {
    test('nacidos un 29 de febrero', () {
      final DateTime birth = DateTime(2000, 2, 29);
      expect(
        BiometricFormulas.calculateDynamicAge(birth, DateTime(2026, 2, 28)),
        closeTo(26, 0.01),
      );
      expect(
        BiometricFormulas.calculateDynamicAge(birth, DateTime(2028, 2, 29)),
        closeTo(28, 0.01),
      );
    });

    test('fecha de nacimiento futura (reloj mal puesto) no da edades negativas', () {
      expect(BiometricFormulas.calculateDynamicAge(DateTime(2030, 1, 1), DateTime(2026, 1, 1)), 0);
    });
  });
}
