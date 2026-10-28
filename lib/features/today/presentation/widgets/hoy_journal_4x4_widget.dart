import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/clock/clock.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/services/text_assistant.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/theme/sc_tokens.dart';
import '../../../../shared/utils/current_date_provider.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/card_header.dart';
import '../../../../shared/widgets/health_card.dart';
import '../../../../shared/widgets/tonal_badge.dart';
import '../../../journal/application/journal_service.dart';
import 'journal_recent_entries.dart';
import 'journal_scale_bar.dart';

/// Único widget gigante 4×4 de NB Selfcare: Diario Personal y Emocional en "Hoy".
///
/// Concentra en un solo lugar (cero duplicidad en Perfil) el registro emocional,
/// niveles de energía y estrés, disparadores de escritura guiada, adjunto de foto local,
/// sugerencia empática local (diccionario determinista) e historial reciente con opción de Deshacer.
class HoyJournal4x4Widget extends ConsumerStatefulWidget {
  const HoyJournal4x4Widget({super.key, required this.dateKey});

  final String dateKey;

  @override
  ConsumerState<HoyJournal4x4Widget> createState() => _HoyJournal4x4WidgetState();
}

class _HoyJournal4x4WidgetState extends ConsumerState<HoyJournal4x4Widget> {
  final TextEditingController _journalController = TextEditingController();

  int _selectedMood = 4;
  int _selectedEnergy = 4;
  int _selectedStress = 2;
  Uint8List? _draftPhoto;
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
        ..showSnackBar(SnackBar(content: Text(context.l10n.todayEscribePrimeroUnasPalabrasPara)));
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
      // Reducida a 1080 px: cabe en la base de datos y viaja en la copia de seguridad.
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 82,
      );
      if (image == null) return;
      final Uint8List bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() => _draftPhoto = bytes);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.todayNoSePudoAdjuntarLa(e.toString()))),
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
        dateKey: drift.Value(
          widget.dateKey.isNotEmpty
              ? widget.dateKey
              : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        ),
        createdAt: drift.Value(timestamp),
        content: drift.Value(text),
        progressPhoto: drift.Value(_draftPhoto),
        moodScore: drift.Value(_selectedMood),
        energyLevel: drift.Value(_selectedEnergy),
        stressLevel: drift.Value(_selectedStress),
        tagsJson: drift.Value(jsonEncode(analysis.tags)),
        aiInsightSummary: drift.Value(analysis.oneLineInsight),
      );

      final ({int entryId, int coins}) saved = await ref
          .read(journalServiceProvider)
          .save(companion);

      _journalController.clear();
      if (mounted) {
        setState(() => _draftPhoto = null);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                saved.coins > 0
                    ? context.l10n.todayReflexionGuardadaEnTuDiario((saved.coins).toString())
                    : context.l10n.todayReflexionGuardadaEnTuDiario2,
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
      padding: const EdgeInsets.all(ScSpace.l + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CardHeader(
            title: context.l10n.todayDiarioPersonal,
            subtitle: context.l10n.todayEspacioPrivado44RegistraTu,
            icon: Icons.menu_book_rounded,
            tone: c.accent,
            trailing: TonalBadge(
              label: context.l10n.todayTexto3(AppConstants.coinsJournalEntry.toString()),
            ),
          ),

          const SizedBox(height: 16),

          // 1. Selector expresivo de Estado de Ánimo (5 tarjetas flexibles sin truncar)
          Text(context.l10n.todayComoTeSientesEnEste, style: context.type.label),
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
              return Column(children: <Widget>[energyBox, const SizedBox(height: 8), stressBox]);
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
                label: Text(prompt.chip),
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
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 14.5, color: c.text, height: 1.45),
            decoration: InputDecoration(hintText: context.l10n.todayEscribeSinPrisaLoQue),
          ),

          if (_draftPhoto case final Uint8List photo) ...<Widget>[
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.topRight,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    photo,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheHeight: 420,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.todayQuitarFoto,
                  icon: const Icon(AppIcons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => setState(() => _draftPhoto = null),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // 5. Acciones secundarias (misma altura aunque una ocupe dos líneas)
          // + botón principal abajo.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickProgressPhoto,
                    icon: Icon(Icons.add_photo_alternate_outlined, size: 17, color: c.text2),
                    label: Text(context.l10n.todayAdjuntarFoto),
                  ),
                ),
                const SizedBox(width: ScSpace.s),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _autoSuggestEmotionFromText,
                    icon: Icon(AppIcons.suggest, size: 17, color: c.isFlat ? c.text : c.accent),
                    label: Text(context.l10n.todaySugerirEstado),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveEntry,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                context.l10n.todayGuardarEnMiDiario(AppConstants.coinsJournalEntry.toString()),
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
