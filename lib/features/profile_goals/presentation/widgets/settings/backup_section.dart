import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/l10n/l10n.dart';
import '../../../../../core/services/backup_service.dart';
import '../../../../../shared/theme/sc_colors.dart';
import '../../../../../shared/theme/sc_theme.dart';
import '../../../../../shared/widgets/app_icons.dart';
import '../../../../../shared/widgets/health_card.dart';
import '../../../../../shared/widgets/section_head.dart';

/// Copia de seguridad y restauración.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key, required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScColors c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHead(
          title: context.l10n.settingsPortabilidadYRespaldoLocal,
          subtitle: context.l10n.settingsTusDatosSon100Tuyos,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        HealthCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.settingsCopiaAtomicaSqliteVacuumInto,
                style: TextStyle(
                  fontFamily: ScFonts.display,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.settingsGeneraUnaCopiaIntegraY,
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
                  label: Text(
                    context.l10n.settingsExportarYCompartirSqlite,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    unawaited(HapticFeedback.selectionClick());
                    await ref.read(backupServiceProvider).shareDatabaseBackup();
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(AppIcons.restore, size: 18),
                  label: Text(
                    context.l10n.settingsRestaurarRespaldoSqlite,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: onRestore,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
