import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../../app/app_sync_coordinator.dart';
import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/platform/health_connect_gateway.dart';
import '../../../core/platform/system_permissions.dart';
import '../../../core/services/backup_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/widgets/section_head.dart';
import '../../today/application/health_sync_service.dart';
import '../../today/application/movement_nudge_service.dart';
import '../application/profile_queries.dart';
import 'widgets/settings/backup_section.dart';
import 'widgets/settings/devices_section.dart';
import 'widgets/settings/modules_section.dart';
import 'widgets/settings/permissions_section.dart';
import 'widgets/settings/reminders_section.dart';
import 'widgets/settings/theme_picker.dart';

/// Subpágina dedicada a la configuración global de NB Selfcare:
/// - Aspecto y Pantalla (22 temas visuales de alta gama)
/// - Dispositivos y Conectividad (Báscula Xiaomi BLE y Android Health Connect)
/// - Portabilidad y Respaldo Local (SQLite VACUUM INTO atómico)
/// - Permisos del Sistema (evaluación dinámica y reactiva en tiempo real)
/// - Recordatorios locales del santuario
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen>
    with WidgetsBindingObserver {
  // Estados de evaluación de permisos del sistema
  bool _hasBluetooth = false;
  bool _hasHealthConnect = false;
  bool _hasCamera = false;
  bool _hasNotifications = false;
  bool _hasExactAlarm = false;
  bool _isLoadingPerms = true;
  MovementNudgeStatus _movementStatus = MovementNudgeStatus.disabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_evaluateAllPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-evaluar permisos siempre al volver desde Ajustes del Teléfono
      unawaited(_evaluateAllPermissions());
    }
  }

  /// Evalúa en tiempo real los permisos del dispositivo para mantener
  /// sincronizada la interfaz si el usuario los altera desde el sistema.
  Future<void> _evaluateAllPermissions() async {
    final SystemPermissions permissions = ref.read(systemPermissionsProvider);
    final HealthConnectGateway healthConnect = ref.read(healthConnectGatewayProvider);
    final MovementNudgeService movementService = ref.read(movementNudgeServiceProvider);

    bool bleGranted = false;
    try {
      bleGranted = await UniversalBle.hasPermissions().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => false,
      );
    } on Exception {
      bleGranted = false;
    }

    final List<bool> granted = await Future.wait(<Future<bool>>[
      healthConnect.hasPermissions(),
      permissions.isGranted(AppPermission.camera),
      permissions.isGranted(AppPermission.notifications),
      permissions.isGranted(AppPermission.exactAlarms),
    ]);

    final MovementNudgeStatus movement = await movementService.status();

    if (mounted) {
      setState(() {
        _movementStatus = movement;
        _hasBluetooth = bleGranted;
        _hasHealthConnect = granted[0];
        _hasCamera = granted[1];
        _hasNotifications = granted[2];
        _hasExactAlarm = granted[3];
        _isLoadingPerms = false;
      });
    }
  }

  Future<void> _requestBlePermission() async {
    try {
      await UniversalBle.requestPermissions();
    } on Exception {
      // El usuario puede conceder Bluetooth más tarde desde Ajustes del sistema.
    }
    await _evaluateAllPermissions();
  }

  Future<void> _requestHealthConnectPermission() async {
    final HealthConnectGateway healthConnect = ref.read(healthConnectGatewayProvider);
    final HealthConnectAvailability availability = await healthConnect.availability();
    if (availability != HealthConnectAvailability.available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (availability) {
              HealthConnectAvailability.updateRequired =>
                context.l10n.settingsActualizaHealthConnectDesdeGoogle,
              HealthConnectAvailability.notInstalled =>
                context.l10n.settingsInstalaHealthConnectDesdeGoogle,
              _ => context.l10n.settingsHealthConnectNoEstaDisponible,
            }),
          ),
        );
      }
      return;
    }
    await healthConnect.requestPermissions();
    await ref.read(healthSyncServiceProvider).syncRecentDays();
    await _evaluateAllPermissions();
  }

  Future<void> _requestCameraPermission() async {
    await ref.read(systemPermissionsProvider).request(AppPermission.camera);
    await _evaluateAllPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    await ref.read(systemPermissionsProvider).request(AppPermission.notifications);
    await _evaluateAllPermissions();
  }

  Future<void> _requestExactAlarmPermission() async {
    await ref.read(systemPermissionsProvider).request(AppPermission.exactAlarms);
    await _evaluateAllPermissions();
  }

  Future<void> _handleRestoreBackup() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(context.l10n.settingsRestaurarRespaldoSqlite),
        content: Text(
          context.l10n.settingsSeVerificaraLaIntegridadAtomica,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.settingsElegirArchivo),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    final result =
        await ref.read(backupServiceProvider).importDatabaseFromPicker();
    if (!mounted || result.cancelled) return;
    if (result.restored) {
      await ref.read(appSyncCoordinatorProvider).sync();
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.restored
              ? context.l10n.settingsBaseDeDatosRestauradaCon: context.l10n.settingsElArchivoSeleccionadoNoEs,
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final AsyncValue<UserProfile?> profileAsync =
        ref.watch(userProfileStreamProvider);
    final UserProfile? profile = profileAsync.value;
    final String currentThemeKey = ref.watch(themeControllerProvider);
    final List<Reminder> reminders =
        ref.watch(allRemindersStreamProvider).value ?? const <Reminder>[];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.settingsAjustesDeLaAplicacion,
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        leading: BackButton(color: c.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          // ==========================================
          // 1. Aspecto y Pantalla (22 Temas)
          // ==========================================
          SectionHead(
            title: context.l10n.settingsAspectoYPantalla,
            subtitle: context.l10n.settings22TemasVisualesDeAlta,
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
          const SizedBox(height: 8),
          ThemePicker(
            currentKey: currentThemeKey,
            onSelect: (String key) {
              unawaited(HapticFeedback.selectionClick());
              unawaited(ref.read(themeControllerProvider.notifier).selectTheme(key));
            },
          ),

          const SizedBox(height: 24),
          RemindersSection(
            reminders: reminders,
            movementStatus: _movementStatus,
            onMovementChanged: (MovementNudgeStatus next) {
              if (mounted) setState(() => _movementStatus = next);
            },
          ),
          const SizedBox(height: 24),
          DevicesSection(
            profile: profile,
            hasHealthConnect: _hasHealthConnect,
            onConnectHealth: _requestHealthConnectPermission,
          ),
          const SizedBox(height: 24),
          ModulesSection(profile: profile),
          const SizedBox(height: 24),
          PermissionsSection(
            isLoading: _isLoadingPerms,
            hasBluetooth: _hasBluetooth,
            hasCamera: _hasCamera,
            hasHealthConnect: _hasHealthConnect,
            hasNotifications: _hasNotifications,
            hasExactAlarm: _hasExactAlarm,
            onRefresh: _evaluateAllPermissions,
            onRequestBluetooth: _requestBlePermission,
            onRequestCamera: _requestCameraPermission,
            onRequestHealthConnect: _requestHealthConnectPermission,
            onRequestNotifications: _requestNotificationPermission,
            onRequestExactAlarm: _requestExactAlarmPermission,
          ),
          const SizedBox(height: 24),
          BackupSection(onRestore: _handleRestoreBackup),
        ],
      ),
    );
  }
}
