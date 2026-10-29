import '../../../core/domain/enums.dart';
import '../../../shared/utils/date_time_extensions.dart';

/// Chequeo preventivo del catálogo: cada cuánto se recomienda y a quién.
///
/// Intervalos orientativos tomados de la Ruta de Promoción y Mantenimiento de
/// la Salud de Colombia (Resolución 3280 de 2018) y de la OMS. La persona puede
/// cambiar cualquier intervalo: su médico manda.
class CheckupSpec {
  const CheckupSpec({
    required this.key,
    required this.intervalMonths,
    this.sex,
    this.minAge = 0,
    this.maxAge = 200,
    this.youngerIntervalMonths,
    this.youngerUntilAge,
  });

  final String key;
  final int intervalMonths;

  /// `null` = para cualquier sexo.
  final BiologicalSex? sex;
  final int minAge;
  final int maxAge;

  /// Intervalo distinto por debajo de [youngerUntilAge] (citología antes de los 30).
  final int? youngerIntervalMonths;
  final int? youngerUntilAge;

  bool appliesTo(BiologicalSex who, int age) =>
      (sex == null || sex == who) && age >= minAge && age <= maxAge;

  int intervalFor(int age) {
    final int? younger = youngerIntervalMonths;
    final int? until = youngerUntilAge;
    return younger != null && until != null && age < until ? younger : intervalMonths;
  }
}

abstract final class CheckupCatalog {
  static const String custom = 'custom';

  static const List<CheckupSpec> all = <CheckupSpec>[
    CheckupSpec(key: 'dental', intervalMonths: 12),
    CheckupSpec(key: 'general', intervalMonths: 24, minAge: 18),
    CheckupSpec(key: 'vision', intervalMonths: 24),
    CheckupSpec(key: 'blood_pressure', intervalMonths: 12, minAge: 18),
    CheckupSpec(key: 'lipids_glucose', intervalMonths: 60, minAge: 18),
    CheckupSpec(
      key: 'cervical',
      intervalMonths: 60,
      sex: BiologicalSex.female,
      minAge: 25,
      maxAge: 65,
      youngerIntervalMonths: 36,
      youngerUntilAge: 30,
    ),
    CheckupSpec(
      key: 'mammography',
      intervalMonths: 24,
      sex: BiologicalSex.female,
      minAge: 50,
      maxAge: 69,
    ),
    CheckupSpec(
      key: 'prostate',
      intervalMonths: 60,
      sex: BiologicalSex.male,
      minAge: 50,
      maxAge: 75,
    ),
    CheckupSpec(key: 'colorectal', intervalMonths: 24, minAge: 50, maxAge: 75),
    CheckupSpec(key: 'bone_density', intervalMonths: 24, sex: BiologicalSex.female, minAge: 65),
    CheckupSpec(key: 'flu_vaccine', intervalMonths: 12, minAge: 60),
    CheckupSpec(key: 'tetanus', intervalMonths: 120, minAge: 18),
  ];

  static CheckupSpec? byKey(String key) {
    for (final CheckupSpec s in all) {
      if (s.key == key) return s;
    }
    return null;
  }

  /// Chequeos que se proponen por defecto para esta persona.
  static List<CheckupSpec> suggestedFor(BiologicalSex sex, int age) =>
      all.where((CheckupSpec s) => s.appliesTo(sex, age)).toList();
}

/// Estado de un chequeo. Sin "vencido": solo lo que toca y cuándo.
enum CheckupStatus { neverDone, upToDate, dueSoon, due }

class CheckupDue {
  const CheckupDue({required this.status, this.nextDue, this.daysUntil});

  final CheckupStatus status;
  final DateTime? nextDue;

  /// Días hasta la próxima fecha (negativo si ya toca).
  final int? daysUntil;

  /// Días de antelación con los que un chequeo pasa a "pronto".
  static const int soonWindowDays = 30;

  static CheckupDue evaluate({
    required DateTime? lastDone,
    required int intervalMonths,
    required DateTime today,
  }) {
    if (lastDone == null) return const CheckupDue(status: CheckupStatus.neverDone);
    final DateTime next = DateTime(lastDone.year, lastDone.month + intervalMonths, lastDone.day);
    final int days = next.calendarDaysSince(today);
    final CheckupStatus status = days <= 0
        ? CheckupStatus.due
        : (days <= soonWindowDays ? CheckupStatus.dueSoon : CheckupStatus.upToDate);
    return CheckupDue(status: status, nextDue: next, daysUntil: days);
  }
}
