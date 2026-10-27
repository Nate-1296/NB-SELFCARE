import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fuente única de la hora actual.
///
/// Toda la app obtiene "ahora" a través de [clockProvider] para que los tests
/// puedan fijar el instante (medianoche, cambios de horario, rachas, ayunos)
/// sin depender del reloj real del sistema.
class Clock {
  const Clock();

  /// Reloj detenido en [instant]; útil en tests y vistas previas.
  const factory Clock.fixed(DateTime instant) = _FixedClock;

  DateTime now() => DateTime.now();
}

class _FixedClock extends Clock {
  const _FixedClock(this._instant);

  final DateTime _instant;

  @override
  DateTime now() => _instant;
}

final clockProvider = Provider<Clock>((Ref ref) => const Clock());
