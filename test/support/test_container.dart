import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nb_selfcare/core/clock/clock.dart';
import 'package:nb_selfcare/core/database/app_database.dart';
import 'package:nb_selfcare/core/platform/health_connect_gateway.dart';
import 'package:nb_selfcare/core/platform/notification_gateway.dart';

import 'fake_platform.dart';

/// Contenedor de Riverpod sobre una base de datos de prueba y un reloj fijo,
/// para ejercitar los casos de uso reales (servicios de `application/`).
///
/// Los puertos nativos se sustituyen por fakes inspeccionables.
ProviderContainer createTestContainer(
  AppDatabase db, {
  DateTime? now,
  FakeHealthConnectGateway? healthConnect,
  FakeNotificationGateway? notifications,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(Clock.fixed(now ?? DateTime(2026, 10, 23, 12))),
      healthConnectGatewayProvider
          .overrideWithValue(healthConnect ?? FakeHealthConnectGateway(granted: false)),
      notificationGatewayProvider.overrideWithValue(notifications ?? FakeNotificationGateway()),
    ],
  );
}
