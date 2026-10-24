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

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/journal_dao.dart';
import '../../../../core/services/local_ai_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/current_date_provider.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/health_card.dart';

/// Único widget gigante 4×4 de NB Selfcare: Diario Personal y Emocional en "Hoy".
///
/// Concentra en un solo lugar (cero duplicidad en Perfil) el registro emocional,
/// niveles de energía y estrés, disparadores de escritura guiada, adjunto de foto local,
/// sugerencia empática con IA local e historial reciente con opción de Deshacer.
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
  bool _showAllRecent = false;

  static const List<({String emoji, String label})> _moodOptions =
      <({String emoji, String label})>[
    (emoji: '😞', label: 'Difícil'),
    (emoji: '😐', label: 'Neutro'),
    (emoji: '🙂', label: 'Bien'),
    (emoji: '😊', label: 'Genial'),
    (emoji: '🤩', label: 'Radiante'),
  ];

  static const List<({String chip, String starter})> _quickPrompts =
      <({String chip, String starter})>[
    (chip: 'Gratitud de hoy', starter: 'Hoy agradezco profundamente '),
    (chip: 'Sensación corporal', starter: 'Mi cuerpo hoy se siente '),
    (chip: 'Pequeño logro', starter: 'Algo que hice bien por mí hoy fue '),
    (chip: 'Soltar tensión', starter: 'Dejo ir la preocupación sobre '),
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
          const SnackBar(
            content: Text(
              'Escribe primero unas palabras para que la IA sugiera tu estado.',
            ),
          ),
        );
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    final analysis = await ref.read(localAiServiceProvider).analyzeJournal(text);
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
          'progress_${DateTime.now().millisecondsSinceEpoch}$ext',
        ),
      );
      await File(image.path).copy(dest.path);

      if (!mounted) return;
      setState(() => _draftPhotoPath = dest.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo adjuntar la imagen: $e')),
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
      final DateTime timestamp = DateTime.now();
      final localAi = ref.read(localAiServiceProvider);
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

      await ref.read(journalDaoProvider).insertEntry(companion);

      _journalController.clear();
      if (mounted) {
        setState(() => _draftPhotoPath = null);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                '¡Reflexión guardada en tu Diario! (+${AppConstants.coinsJournalEntry} Monedas Nibi 🪙)',
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
    final dao = ref.read(journalDaoProvider);
    await dao.deleteEntry(entry.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Entrada de diario eliminada.'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              unawaited(dao.restoreEntry(entry));
            },
          ),
        ),
      );
  }

  static List<String> _decodeTags(String rawJson) {
    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final journalDao = ref.watch(journalDaoProvider);

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
                      'Diario Personal',
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Espacio privado 4×4 · Registra tu estado emocional y alimenta tus correlaciones locales',
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
                  '+${AppConstants.coinsJournalEntry} 🪙',
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
            '¿Cómo te sientes en este momento?',
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(_moodOptions.length, (int i) {
              final int score = i + 1;
              final bool selected = _selectedMood == score;
              final item = _moodOptions[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() => _selectedMood = score);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? (c.isFlat ? c.bg3 : c.soft)
                            : c.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? c.accent : c.line,
                          width: selected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            item.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 10.5,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                              color: selected ? c.text : c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          // 2. Energía y Estrés adaptables al ancho (nunca se cortan)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool sideBySide = constraints.maxWidth >= 340;
              final Widget energyBox = _MetricScaleBar(
                label: 'Energía física',
                value: _selectedEnergy,
                activeColor: c.accent,
                onChanged: (int v) => setState(() => _selectedEnergy = v),
              );
              final Widget stressBox = _MetricScaleBar(
                label: 'Nivel de estrés',
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
            children: _quickPrompts.map((prompt) {
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
                  'Escribe sin prisa lo que piensas, agradeces o aprendiste hoy...',
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
                  tooltip: 'Quitar foto',
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
                  'Adjuntar foto',
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
                icon: Icon(AppIcons.ai, size: 16, color: c.accent),
                label: Text(
                  'Sugerir estado con IA',
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
              label: const Text(
                'Guardar en mi diario (+${AppConstants.coinsJournalEntry} 🪙)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),

          // 6. Historial reciente integrado dentro del bloque 4×4
          StreamBuilder<List<JournalEntry>>(
            stream: journalDao.watchRecentEntries(limit: _showAllRecent ? 6 : 2),
            builder:
                (BuildContext context, AsyncSnapshot<List<JournalEntry>> snap) {
              final List<JournalEntry> entries =
                  snap.data ?? const <JournalEntry>[];
              if (entries.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 16),
                  Divider(color: c.line, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Reflexiones recientes',
                        style: TextStyle(
                          fontFamily: ScFonts.display,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      if (entries.length >= 2)
                        TextButton(
                          onPressed: () =>
                              setState(() => _showAllRecent = !_showAllRecent),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            _showAllRecent ? 'Ver menos' : 'Ver más',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final JournalEntry entry in entries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: c.isFlat ? c.line2 : c.line,
                          width: c.isFlat ? 1.3 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                _moodOptions[((entry.moodScore ?? 3) - 1)
                                        .clamp(0, 4)]
                                    .emoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${entry.dateKey} · Energía ${entry.energyLevel ?? 3}/5 · Estrés ${entry.stressLevel ?? 2}/5',
                                  softWrap: true,
                                  style: TextStyle(
                                    fontFamily: ScFonts.ui,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.text3,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Eliminar entrada',
                                icon: Icon(
                                  AppIcons.delete,
                                  size: 16,
                                  color: c.text3,
                                ),
                                onPressed: () => _deleteWithUndo(entry),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.content,
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: ScFonts.ui,
                              fontSize: 13.5,
                              color: c.text,
                              height: 1.4,
                            ),
                          ),
                          if (entry.progressPhotoPath != null &&
                              File(entry.progressPhotoPath!).existsSync()) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(entry.progressPhotoPath!),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          if (entry.aiInsightSummary != null &&
                              entry.aiInsightSummary!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: c.bg3,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      AppIcons.ai,
                                      size: 14,
                                      color: c.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      entry.aiInsightSummary!,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontFamily: ScFonts.ui,
                                        fontSize: 12,
                                        color: c.text2,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Builder(
                            builder: (BuildContext context) {
                              final List<String> tags =
                                  _decodeTags(entry.tagsJson);
                              if (tags.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: tags
                                      .map(
                                        (String t) => Text(
                                          '#$t',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: c.accent,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricScaleBar extends StatelessWidget {
  const _MetricScaleBar({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color activeColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.isFlat ? c.line2 : c.line,
          width: c.isFlat ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontFamily: ScFonts.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(5, (int idx) {
              final int level = idx + 1;
              final bool selected = value == level;
              return GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onChanged(level);
                },
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? activeColor : c.bg3,
                    shape: BoxShape.circle,
                    border: c.isFlat && selected
                        ? Border.all(color: c.text, width: 1.4)
                        : null,
                  ),
                  child: Text(
                    '$level',
                    style: TextStyle(
                      fontFamily: ScFonts.display,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? c.ink : c.text2,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

