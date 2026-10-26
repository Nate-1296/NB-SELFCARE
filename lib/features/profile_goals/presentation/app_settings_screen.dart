import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/reminders_dao.dart';
import '../../../core/database/daos/user_profile_dao.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/health_connect_service.dart';
import '../../../shared/theme/sc_colors.dart';
import '../../../shared/theme/sc_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/health_card.dart';
import '../../../shared/widgets/section_head.dart';

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
    final HealthConnectService hc = ref.read(healthConnectServiceProvider);

    bool bleGranted = false;
    try {
      bleGranted = await UniversalBle.hasPermissions().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => false,
      );
    } catch (_) {
      bleGranted = false;
    }

    bool hcGranted = false;
    try {
      hcGranted = await hc.checkPermissions().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => false,
      );
    } catch (_) {
      hcGranted = false;
    }

    bool camGranted = false;
    try {
      camGranted = await hc
          .checkAppPermission('android.permission.CAMERA')
          .timeout(
            const Duration(milliseconds: 300),
            onTimeout: () => false,
          );
    } catch (_) {
      camGranted = false;
    }

    bool notifGranted = false;
    try {
      notifGranted = await hc
          .checkAppPermission('android.permission.POST_NOTIFICATIONS')
          .timeout(
            const Duration(milliseconds: 300),
            onTimeout: () => false,
          );
    } catch (_) {
      notifGranted = false;
    }

    bool alarmGranted = false;
    try {
      alarmGranted = await hc
          .checkAppPermission('android.permission.SCHEDULE_EXACT_ALARM')
          .timeout(
            const Duration(milliseconds: 300),
            onTimeout: () => false,
          );
    } catch (_) {
      alarmGranted = false;
    }

    if (mounted) {
      setState(() {
        _hasBluetooth = bleGranted;
        _hasHealthConnect = hcGranted;
        _hasCamera = camGranted;
        _hasNotifications = notifGranted;
        _hasExactAlarm = alarmGranted;
        _isLoadingPerms = false;
      });
    }
  }

  Future<void> _requestBlePermission() async {
    try {
      await UniversalBle.requestPermissions();
    } catch (_) {}
    await _evaluateAllPermissions();
  }

  Future<void> _requestHealthConnectPermission() async {
    final HealthConnectService hc = ref.read(healthConnectServiceProvider);
    await hc.requestPermissions();
    await _evaluateAllPermissions();
  }

  Future<void> _requestCameraPermission() async {
    final HealthConnectService hc = ref.read(healthConnectServiceProvider);
    await hc.requestAppPermission('android.permission.CAMERA');
    await _evaluateAllPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    final HealthConnectService hc = ref.read(healthConnectServiceProvider);
    await hc.requestAppPermission('android.permission.POST_NOTIFICATIONS');
    await _evaluateAllPermissions();
  }

  Future<void> _requestExactAlarmPermission() async {
    final HealthConnectService hc = ref.read(healthConnectServiceProvider);
    await hc.requestAppPermission('android.permission.SCHEDULE_EXACT_ALARM');
    await _evaluateAllPermissions();
  }

  Future<void> _handleRestoreBackup() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Restaurar Respaldo .sqlite'),
        content: const Text(
          'Se verificará la integridad atómica del archivo seleccionado y se reemplazarán los registros actuales. ¿Deseas seleccionar el archivo?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elegir archivo'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    final result =
        await ref.read(backupServiceProvider).importDatabaseFromPicker();
    if (!mounted || result.cancelled) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.restored
              ? '¡Base de datos restaurada con éxito! Todos tus paneles están al día.'
              : 'El archivo seleccionado no es un respaldo válido de NB Selfcare.',
        ),
      ),
    );
  }

  static String _formatMinutesAsTime(int totalMinutes) {
    final int h = (totalMinutes ~/ 60).clamp(0, 23);
    final int m = (totalMinutes % 60).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String _reminderTitle(String type) {
    return switch (type) {
      'morning_weigh_in' => 'Pesaje matutino en ayunas',
      'hydration' => 'Pausa de hidratación activa',
      'fasting_close' => 'Cierre de ventana alimenticia',
      'journal' => 'Reflexión nocturna sin pantallas',
      'tape_measure' => 'Control quincenal US Navy',
      _ => 'Recordatorio personal',
    };
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
          'Ajustes de la Aplicación',
          style: TextStyle(
            fontFamily: ScFonts.display,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          // ==========================================
          // 1. Aspecto y Pantalla (22 Temas)
          // ==========================================
          const SectionHead(
            title: 'Aspecto y Pantalla',
            subtitle: '22 temas visuales de alta gama con soporte NXTPAPER',
            padding: EdgeInsets.symmetric(vertical: 4),
          ),
          const SizedBox(height: 8),
          HealthCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              children: <Widget>[
                for (final ScThemeDef themeDef in kScThemes)
                  _ThemeSelectionTile(
                    def: themeDef,
                    isSelected: themeDef.key == currentThemeKey,
                    onSelect: () async {
                      unawaited(HapticFeedback.selectionClick());
                      await ref
                          .read(themeControllerProvider.notifier)
                          .selectTheme(themeDef.key);
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==========================================
          // 2. Dispositivos y Conectividad
          // ==========================================
          const SectionHead(
            title: 'Dispositivos y Conectividad',
            subtitle: 'Báscula Xiaomi BLE y puente local Health Connect',
            padding: EdgeInsets.symmetric(vertical: 4),
          ),
          const SizedBox(height: 8),
          HealthCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                // Báscula Xiaomi
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.bg3 : c.soft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(AppIcons.bascula, color: c.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Xiaomi Mi Body Composition Scale 2',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (profile?.scaleMacAddress != null &&
                                    profile!.scaleMacAddress!.isNotEmpty)
                                ? 'Vinculada: ${profile.scaleMacAddress}'
                                : 'Escaneo pasivo disponible en Cuerpo',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11.5,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (profile?.scaleMacAddress != null &&
                        profile!.scaleMacAddress!.isNotEmpty)
                      OutlinedButton(
                        onPressed: () async {
                          unawaited(HapticFeedback.selectionClick());
                          await ref.read(userProfileDaoProvider).updateProfile(
                                const UserProfilesCompanion(
                                  scaleMacAddress: drift.Value(null),
                                ),
                              );
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Olvidar'),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.bg3,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.isFlat ? c.line2 : c.line),
                        ),
                        child: Text(
                          'BLE Listo',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.text2,
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: c.line),
                ),
                // Health Connect
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.bg3 : c.soft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(AppIcons.corazon, color: c.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Android Health Connect',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hasHealthConnect
                                ? 'Sincronizado: peso, grasa, pasos y agua'
                                : 'Puente local no conectado aún',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11.5,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _requestHealthConnectPermission,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(_hasHealthConnect ? 'Gestionar' : 'Conectar'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==========================================
          // 3. Módulos y Enfoque de Autocuidado
          // ==========================================
          const SectionHead(
            title: 'Módulos y Enfoque',
            subtitle: 'Adapta los pilares visibles a tus necesidades reales',
            padding: EdgeInsets.symmetric(vertical: 4),
          ),
          const SizedBox(height: 8),
          HealthCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                // Ayuno Intermitente
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.isFlat ? c.bg3 : c.soft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(AppIcons.fasting, color: c.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Ayuno Intermitente',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (profile?.isFastingEnabled ?? true)
                                ? 'Cronómetro y fases celulares activos'
                                : 'Módulo replegado para simplificar la UI',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 11.5,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: profile?.isFastingEnabled ?? true,
                      onChanged: (bool val) async {
                        unawaited(HapticFeedback.selectionClick());
                        await ref.read(userProfileDaoProvider).updateFastingEnabled(val);
                      },
                    ),
                  ],
                ),

                // Salud Femenina (ÚNICAMENTE visible si el sexo biológico es femenino)
                if (profile?.biologicalSex == 'female') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: c.line),
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.isFlat ? c.bg3 : c.soft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(Icons.female_rounded, color: c.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Salud Femenina y Ciclo Menstrual',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (profile?.isCycleTrackingEnabled ?? false)
                                  ? 'Sincronización hormonal con TDEE y báscula'
                                  : 'Desactivado',
                              style: TextStyle(
                                fontFamily: ScFonts.ui,
                                fontSize: 11.5,
                                color: c.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: profile?.isCycleTrackingEnabled ?? false,
                        onChanged: (bool val) async {
                          unawaited(HapticFeedback.selectionClick());
                          await ref.read(userProfileDaoProvider).updateCycleTrackingEnabled(val);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==========================================
          // 4. Permisos del Sistema
          // ==========================================
          SectionHead(
            title: 'Permisos del Sistema',
            subtitle: 'Evaluación viva para prevenir desincronizaciones',
            actionLabel: 'Reevaluar',
            onAction: _evaluateAllPermissions,
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
          const SizedBox(height: 8),
          HealthCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: _isLoadingPerms
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: <Widget>[
                      _PermissionRow(
                        icon: Icons.bluetooth_rounded,
                        title: 'Bluetooth y Escaneo',
                        subtitle: 'Para recibir pesajes de la báscula Mi Scale 2',
                        isGranted: _hasBluetooth,
                        onRequest: _requestBlePermission,
                      ),
                      Divider(height: 16, color: c.line),
                      _PermissionRow(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Cámara',
                        subtitle: 'Para escanear códigos de barras de alimentos',
                        isGranted: _hasCamera,
                        onRequest: _requestCameraPermission,
                      ),
                      Divider(height: 16, color: c.line),
                      _PermissionRow(
                        icon: Icons.favorite_rounded,
                        title: 'Health Connect',
                        subtitle: 'Intercambio seguro de métricas en tu dispositivo',
                        isGranted: _hasHealthConnect,
                        onRequest: _requestHealthConnectPermission,
                      ),
                      Divider(height: 16, color: c.line),
                      _PermissionRow(
                        icon: Icons.notifications_active_rounded,
                        title: 'Notificaciones Locales',
                        subtitle: 'Alertas de ayuno y rutinas sin telemetría',
                        isGranted: _hasNotifications,
                        onRequest: _requestNotificationPermission,
                      ),
                      Divider(height: 16, color: c.line),
                      _PermissionRow(
                        icon: Icons.alarm_rounded,
                        title: 'Alarmas Exactas',
                        subtitle: 'Precisión exacta para temporizador de ayuno',
                        isGranted: _hasExactAlarm,
                        onRequest: _requestExactAlarmPermission,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final hc = ref.read(healthConnectServiceProvider);
                            await hc.openAppSettings();
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text(
                            'Abrir Ajustes del Teléfono',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ==========================================
          // 4. Portabilidad y Respaldo Local
          // ==========================================
          const SectionHead(
            title: 'Portabilidad y Respaldo Local',
            subtitle: 'Tus datos son 100% tuyos (Cero Nube / SQLite Puro)',
            padding: EdgeInsets.symmetric(vertical: 4),
          ),
          const SizedBox(height: 8),
          HealthCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Copia Atómica SQLite (VACUUM INTO)',
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Genera una copia íntegra y verificada de tu base de datos SQLite sin cerrar la app, o restaura un respaldo previo.',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12,
                    color: c.text2,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 19),
                    label: const Text(
                      'Exportar y Compartir .sqlite',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      unawaited(HapticFeedback.selectionClick());
                      await ref
                          .read(backupServiceProvider)
                          .shareDatabaseBackup();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(AppIcons.restore, size: 18),
                    label: const Text(
                      'Restaurar Respaldo .sqlite',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleRestoreBackup,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==========================================
          // 5. Recordatorios del Santuario
          // ==========================================
          const SectionHead(
            title: 'Recordatorios del Santuario',
            subtitle: 'Horarios locales ajustables para tus rutinas',
            padding: EdgeInsets.symmetric(vertical: 4),
          ),
          const SizedBox(height: 8),
          HealthCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14),
            child: reminders.isEmpty
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Activa tus 4 rutinas sugeridas (pesaje, agua, ayuno y reflexión).',
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            color: c.text2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: () => ref
                            .read(remindersDaoProvider)
                            .seedDefaultRemindersIfEmpty(),
                        icon: const Icon(AppIcons.alarm, size: 16),
                        label: const Text('Activar'),
                      ),
                    ],
                  )
                : Column(
                    children: <Widget>[
                      for (final Reminder rem in reminders)
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            _reminderTitle(rem.reminderType),
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
                                initialTime: TimeOfDay(
                                  hour: rem.timeOfDayMinutes ~/ 60,
                                  minute: rem.timeOfDayMinutes % 60,
                                ),
                              );
                              if (picked != null) {
                                await ref
                                    .read(remindersDaoProvider)
                                    .updateReminderTime(
                                      rem.id,
                                      picked.hour * 60 + picked.minute,
                                    );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Horario: ${_formatMinutesAsTime(rem.timeOfDayMinutes)} (tocar para cambiar)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: c.accent,
                                ),
                              ),
                            ),
                          ),
                          value: rem.isEnabled,
                          onChanged: (bool val) => ref
                              .read(remindersDaoProvider)
                              .toggleReminder(rem.id, val),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 20,
          color: isGranted ? (c.isFlat ? c.text : c.accent) : c.text3,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: ScFonts.ui,
                  fontSize: 11,
                  color: c.text2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isGranted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: c.isFlat ? c.line2 : c.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: c.isFlat ? c.text : c.success,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: c.isFlat ? c.text : c.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Concedido',
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.isFlat ? c.text : c.success,
                  ),
                ),
              ],
            ),
          )
        else
          FilledButton.tonal(
            onPressed: onRequest,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Permitir'),
          ),
      ],
    );
  }
}

class _ThemeSelectionTile extends StatelessWidget {
  const _ThemeSelectionTile({
    required this.def,
    required this.isSelected,
    required this.onSelect,
  });

  final ScThemeDef def;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: <Widget>[
            // Previsualizador circular de color de fondo y acento
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: def.colors.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? def.colors.accent : def.colors.line2,
                  width: isSelected ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: def.colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          def.label,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? c.accent : c.text,
                          ),
                        ),
                      ),
                      if (def.colors.isFlat) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: c.bg3,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.line2),
                          ),
                          child: Text(
                            'Papel',
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: c.text2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    def.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ScFonts.ui,
                      fontSize: 11,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: c.accent, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: c.text3, size: 18),
          ],
        ),
      ),
    );
  }
}

