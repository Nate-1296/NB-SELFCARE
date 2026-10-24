import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'date_time_extensions.dart';

/// Notificador reactivo de la fecha calendario vigente.
///
/// Detecta cambios de medianoche y reanudaciones de la app en segundo plano,
/// evitando que pestañas en `IndexedStack` queden ancladas al día anterior.
class CurrentDateNotifier extends Notifier<DateTime> {
  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;

  @override
  DateTime build() {
    _timer?.cancel();
    _lifecycleListener?.dispose();

    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkRollover());
    _lifecycleListener = AppLifecycleListener(
      onResume: _checkRollover,
    );

    ref.onDispose(() {
      _timer?.cancel();
      _lifecycleListener?.dispose();
    });

    return DateTime.now().startOfDay;
  }

  void _checkRollover() {
    final DateTime nowDay = DateTime.now().startOfDay;
    if (!state.isSameDay(nowDay)) {
      state = nowDay;
    }
  }
}

/// Provider global de la fecha actual (`00:00:00` local).
final currentDateProvider =
    NotifierProvider<CurrentDateNotifier, DateTime>(CurrentDateNotifier.new);

/// Provider global de la clave `YYYY-MM-DD` del día en curso.
final currentDateKeyProvider = Provider<String>((ref) {
  return ref.watch(currentDateProvider).dateKey;
});

