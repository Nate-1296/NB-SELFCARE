import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/platform/system_permissions.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/section_head.dart';

/// Estado de los permisos del sistema, con acceso a concederlos.
class PermissionsSection extends ConsumerWidget {
  const PermissionsSection({
    super.key,
    required this.isLoading,
    required this.hasBluetooth,
    required this.hasCamera,
    required this.hasHealthConnect,
    required this.hasNotifications,
    required this.hasExactAlarm,
    required this.onRefresh,
    required this.onRequestBluetooth,
    required this.onRequestCamera,
    required this.onRequestHealthConnect,
    required this.onRequestNotifications,
    required this.onRequestExactAlarm,
  });

  final bool isLoading;
  final bool hasBluetooth;
  final bool hasCamera;
  final bool hasHealthConnect;
  final bool hasNotifications;
  final bool hasExactAlarm;
  final VoidCallback onRefresh;
  final VoidCallback onRequestBluetooth;
  final VoidCallback onRequestCamera;
  final VoidCallback onRequestHealthConnect;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestExactAlarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(
          title: context.l10n.settingsPermisosDelSistema,
          subtitle: context.l10n.settingsEvaluacionVivaParaPrevenirDesincronizaciones,
          actionLabel: context.l10n.settingsReevaluar,
          onAction: onRefresh,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          child: isLoading
              ? const Center(
                  child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                )
              : Column(
                  children: <Widget>[
                    PermissionRow(
                      icon: Icons.bluetooth_rounded,
                      title: context.l10n.settingsBluetoothYEscaneo,
                      subtitle: context.l10n.settingsParaRecibirPesajesDeLa,
                      isGranted: hasBluetooth,
                      onRequest: onRequestBluetooth,
                    ),
                    Divider(height: 16, color: c.line),
                    PermissionRow(
                      icon: Icons.qr_code_scanner_rounded,
                      title: context.l10n.settingsCamara,
                      subtitle: context.l10n.settingsParaEscanearCodigosDeBarras,
                      isGranted: hasCamera,
                      onRequest: onRequestCamera,
                    ),
                    Divider(height: 16, color: c.line),
                    PermissionRow(
                      icon: Icons.favorite_rounded,
                      title: context.l10n.cuerpoSourceHealthConnect,
                      subtitle: context.l10n.settingsIntercambioSeguroDeMetricasEn,
                      isGranted: hasHealthConnect,
                      onRequest: onRequestHealthConnect,
                    ),
                    Divider(height: 16, color: c.line),
                    PermissionRow(
                      icon: Icons.notifications_active_rounded,
                      title: context.l10n.settingsNotificacionesLocales,
                      subtitle: context.l10n.settingsAlertasDeAyunoYRutinas,
                      isGranted: hasNotifications,
                      onRequest: onRequestNotifications,
                    ),
                    Divider(height: 16, color: c.line),
                    PermissionRow(
                      icon: Icons.alarm_rounded,
                      title: context.l10n.settingsAlarmasExactas,
                      subtitle: context.l10n.settingsRecordatoriosPuntualesSinEllosLlegan,
                      isGranted: hasExactAlarm,
                      onRequest: onRequestExactAlarm,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(systemPermissionsProvider).openAppSettings();
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          context.l10n.settingsAbrirAjustesDelTelefono,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => context.push<void>('/privacidad'),
                        icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                        label: Text(context.l10n.settingsPoliticaDePrivacidad),
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 24),

        // ==========================================
      ],
    );
  }
}

class PermissionRow extends StatelessWidget {
  const PermissionRow({super.key, 
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
        Icon(icon, size: 20, color: isGranted ? (c.isFlat ? c.text : c.accent) : c.text3),
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
                style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11, color: c.text2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isGranted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: c.isFlat ? c.bg3 : c.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.isFlat ? c.text : c.success, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.check_rounded, size: 13, color: c.isFlat ? c.text : c.success),
                const SizedBox(width: 4),
                Text(
                  context.l10n.settingsConcedido,
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
            child: Text(context.l10n.settingsPermitir),
          ),
      ],
    );
  }
}
