import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/text_assistant.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/current_date_provider.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../journal/application/journal_service.dart';
import 'journal_recent_entries.dart';
import 'journal_scale_bar.dart';

/// Único widget gigante 4×4 de NB Selfcare: Diario Personal y Emocional en "Hoy".
///
/// Concentra en un solo lugar (cero duplicidad en Perfil) el registro emocional,
/// niveles de energía y estrés, disparadores de escritura guiada, adjunto de foto local,
/// sugerencia empática local (diccionario determinista) e historial reciente con opción de Deshacer.
class HoyJournal4x4Widget extends ConsumerStatefulWidget {
  const HoyJournal4x4Widget({
    super.key,
    required this.dateKey,
  });

  final String dateKey;

  @override
  ConsumerState<HoyJournal4x4Widget> createState() =>
      _HoyJournal4x4WidgetState();
}

class _HoyJournal4x4WidgetState extends ConsumerState<HoyJournal4x4Widget> {
  final TextEditingController _journalController = TextEditingController();

  int _selectedMood = 4;
  int _selectedEnergy = 4;
  int _selectedStress = 2;
  String? _draftPhotoPath;
  bool _isSaving = false;

  static List<({String chip, String starter})> _quickPrompts(AppLocalizations l10n) =>
      <({String chip, String starter})>[
        (chip: l10n.todayPromptGratitude, starter: l10n.todayPromptGratitudeStarter),
        (chip: l10n.todayPromptBody, starter: l10n.todayPromptBodyStarter),
        (chip: l10n.todayPromptWin, starter: l10n.todayPromptWinStarter),
        (chip: l10n.todayPromptRelease, starter: l10n.todayPromptReleaseStarter),
      ];

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  void _applyPrompt(String starter) {
    unawaited(HapticFeedback.selectionClick());
    final String current = _journalController.text.trim();
    final String updated = current.isEmpty ? starter : '$current\n$starter';
    _journalController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  Future<void> _autoSuggestEmotionFromText() async {
    final String text = _journalController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.todayEscribePrimeroUnasPalabrasPara,
            ),
          ),
        );
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    final analysis = await ref.read(textAssistantProvider).analyzeJournal(text);
    if (!mounted) return;
    setState(() {
      _selectedMood = analysis.moodScore.clamp(1, 5);
      _selectedEnergy = analysis.energyLevel.clamp(1, 5);
      _selectedStress = analysis.stressLevel.clamp(1, 5);
    });
  }

  Future<void> _pickProgressPhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory photosDir =
          Directory(p.join(appDir.path, 'journal_photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final String ext =
          p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path);
      final File dest = File(
        p.join(
          photosDir.path,
          'progress_${ref.read(clockProvider).now().millisecondsSinceEpoch}$ext',
        ),
      );
      await File(image.path).copy(dest.path);

      if (!mounted) return;
      setState(() => _draftPhotoPath = dest.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.todayNoSePudoAdjuntarLa((e).toString()))),
        );
      }
    }
  }

  Future<void> _saveEntry() async {
    final String text = _journalController.text.trim();
    if (text.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    unawaited(HapticFeedback.lightImpact());

    try {
      final DateTime now = ref.read(currentDateProvider);
      final DateTime timestamp = ref.read(clockProvider).now();
      final localAi = ref.read(textAssistantProvider);
      final analysis = await localAi.analyzeJournal(text);

      final companion = JournalEntriesCompanion(
        dateKey: drift.Value(widget.dateKey.isNotEmpty
            ? widget.dateKey
            : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'),
        createdAt: drift.Value(timestamp),
        content: drift.Value(text),
        progressPhotoPath: drift.Value(_draftPhotoPath),
        moodScore: drift.Value(_selectedMood),
        energyLevel: drift.Value(_selectedEnergy),
        stressLevel: drift.Value(_selectedStress),
        tagsJson: drift.Value(jsonEncode(analysis.tags)),
        aiInsightSummary: drift.Value(analysis.oneLineInsight),
      );

      final ({int entryId, int coins}) saved =
          await ref.read(journalServiceProvider).save(companion);

      _journalController.clear();
      if (mounted) {
        setState(() => _draftPhotoPath = null);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                saved.coins > 0
                    ? context.l10n.todayReflexionGuardadaEnTuDiario((saved.coins).toString()): context.l10n.todayReflexionGuardadaEnTuDiario2,
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteWithUndo(JournalEntry entry) async {
    unawaited(HapticFeedback.selectionClick());
    final JournalService service = ref.read(journalServiceProvider);
    await service.delete(entry.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.todayEntradaDeDiarioEliminada),
          action: SnackBarAction(
            label: context.l10n.commonUndo,
            onPressed: () {
              unawaited(service.restore(entry));
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return HealthCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Cabecera amplia sin cortes de texto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.isFlat ? c.bg3 : c.soft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.accent.withValues(alpha: 0.35),
                    width: c.isFlat ? 1.5 : 1.0,
                  ),
                ),
                child: Icon(Icons.menu_book_rounded, size: 20, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.todayDiarioPersonal,
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.todayEspacioPrivado44RegistraTu,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 12,
                        color: c.text2,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: c.isFlat ? c.line2 : c.line,
                    width: c.isFlat ? 1.4 : 1.0,
                  ),
                ),
                child: Text(
                  context.l10n.todayTexto3(AppConstants.coinsJournalEntry.toString()),
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 1. Selector expresivo de Estado de Ánimo (5 tarjetas flexibles sin truncar)
          Text(
            context.l10n.todayComoTeSientesEnEste,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          JournalMoodPicker(
            selected: _selectedMood,
            onChanged: (int score) {
              unawaited(HapticFeedback.selectionClick());
              setState(() => _selectedMood = score);
            },
          ),

          const SizedBox(height: 12),

          // 2. Energía y Estrés adaptables al ancho (nunca se cortan)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool sideBySide = constraints.maxWidth >= 340;
              final Widget energyBox = JournalScaleBar(
                label: context.l10n.todayEnergiaFisica,
                value: _selectedEnergy,
                activeColor: c.accent,
                onChanged: (int v) => setState(() => _selectedEnergy = v),
              );
              final Widget stressBox = JournalScaleBar(
                label: context.l10n.todayNivelDeEstres,
                value: _selectedStress,
                activeColor: c.warning,
                onChanged: (int v) => setState(() => _selectedStress = v),
              );

              if (sideBySide) {
                return Row(
                  children: <Widget>[
                    Expanded(child: energyBox),
                    const SizedBox(width: 8),
                    Expanded(child: stressBox),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  energyBox,
                  const SizedBox(height: 8),
                  stressBox,
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // 3. Disparadores rápidos de reflexión guiada
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickPrompts(context.l10n).map((prompt) {
              return ActionChip(
                visualDensity: VisualDensity.compact,
                backgroundColor: c.bg,
                side: BorderSide(
                  color: c.isFlat ? c.line2 : c.line,
                  width: c.isFlat ? 1.2 : 1.0,
                ),
                label: Text(
                  prompt.chip,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.text2,
                  ),
                ),
                onPressed: () => _applyPrompt(prompt.starter),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // 4. Área amplia de escritura 4×4
          TextField(
            controller: _journalController,
            minLines: 4,
            maxLines: 7,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 14,
              color: c.text,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText:
                  context.l10n.todayEscribeSinPrisaLoQue,
              hintStyle: TextStyle(
                fontFamily: ScFonts.ui,
                fontSize: 13.5,
                color: c.text3,
              ),
              filled: true,
              fillColor: c.bg,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: c.isFlat ? c.line2 : c.line,
                  width: c.isFlat ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.accent, width: 1.8),
              ),
            ),
          ),

          if (_draftPhotoPath != null &&
              File(_draftPhotoPath!).existsSync()) ...<Widget>[
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.topRight,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_draftPhotoPath!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.todayQuitarFoto,
                  icon: const Icon(AppIcons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => setState(() => _draftPhotoPath = null),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // 5. Acciones secundarias + Botón principal cómodo abajo (cero cortes)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _pickProgressPhoto,
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 17,
                  color: c.text2,
                ),
                label: Text(
                  context.l10n.todayAdjuntarFoto,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _autoSuggestEmotionFromText,
                icon: Icon(AppIcons.suggest, size: 16, color: c.accent),
                label: Text(
                  context.l10n.todaySugerirEstado,
                  style: TextStyle(
                    fontFamily: ScFonts.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveEntry,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                context.l10n.todayGuardarEnMiDiario(AppConstants.coinsJournalEntry.toString()),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          // 6. Historial reciente
          JournalRecentEntries(onDelete: _deleteWithUndo),
        ],
      ),
    );
  }
}

