import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/speech_gateway.dart';
import '../../../../core/platform/system_permissions.dart';
import '../../../../core/services/text_assistant.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/utils/number_formats.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../application/food_logging_service.dart';
import 'meal_slot_selector.dart';

/// Subpágina de escritura libre de comidas: extractor determinista local + vista previa editable.
class AiMealDictationSheet extends ConsumerStatefulWidget {
  const AiMealDictationSheet({super.key, required this.dateKey, required this.initialMealType});

  final String dateKey;
  final MealType initialMealType;

  @override
  ConsumerState<AiMealDictationSheet> createState() => _AiMealDictationSheetState();
}

class _AiMealDictationSheetState extends ConsumerState<AiMealDictationSheet> {
  final TextEditingController _textController = TextEditingController();
  late MealType _selectedMealType;
  bool _isProcessing = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  List<ParsedMealItem>? _previewItems;

  List<String> _examples(AppLocalizations l10n) => <String>[
    l10n.food2Huevos80gAvenaY,
    l10n.food200gPechugaDePollo150g,
    l10n.food150gYogurGriegoY30g,
  ];

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;
    unawaited(_checkSpeech());
  }

  @override
  void dispose() {
    if (_isListening) unawaited(ref.read(speechGatewayProvider).stop());
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkSpeech() async {
    final bool available = await ref.read(speechGatewayProvider).isOnDeviceAvailable();
    if (mounted) setState(() => _speechAvailable = available);
  }

  /// Dictado 100 % en el dispositivo: el texto reconocido rellena el campo.
  Future<void> _toggleDictation() async {
    final SpeechGateway speech = ref.read(speechGatewayProvider);
    if (_isListening) {
      await speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final bool granted = await ref
        .read(systemPermissionsProvider)
        .request(AppPermission.microphone);
    if (!granted) return;
    final String prefix = _textController.text.trim();
    final bool started = await speech.start(
      onText: (String text, bool isFinal) {
        if (!mounted) return;
        setState(() {
          _textController.text = prefix.isEmpty
              ? text
              : context.l10n.foodTexto((prefix).toString(), (text).toString());
          _previewItems = null;
          if (isFinal) _isListening = false;
        });
      },
      onDone: () {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() => _isListening = started);
  }

  Future<void> _analyzeText() async {
    final String text = _textController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final result = await ref.read(textAssistantProvider).parseMealText(text);
      if (!mounted) return;
      setState(() {
        _previewItems = List<ParsedMealItem>.of(result.items);
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _adjustPreviewGrams(int index, double delta) {
    final List<ParsedMealItem>? items = _previewItems;
    if (items == null || index < 0 || index >= items.length) return;
    final ParsedMealItem old = items[index];
    final double updatedGrams = (old.grams + delta).clamp(5.0, 3000.0);
    setState(() {
      items[index] = ParsedMealItem(
        searchTerm: old.searchTerm,
        grams: updatedGrams,
        fallbackKcal: old.fallbackKcal,
        fallbackP: old.fallbackP,
        fallbackC: old.fallbackC,
        fallbackF: old.fallbackF,
      );
    });
  }

  Future<void> _confirmAndLog() async {
    final String rawText = _textController.text.trim();
    if (_isProcessing || (rawText.isEmpty && (_previewItems?.isEmpty ?? true))) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final TextAssistant aiService = ref.read(textAssistantProvider);

      List<ParsedMealItem> itemsToLog = _previewItems ?? <ParsedMealItem>[];
      if (itemsToLog.isEmpty) {
        final parsed = await aiService.parseMealText(rawText);
        itemsToLog = parsed.items;
      }

      if (itemsToLog.isEmpty) return;

      final FoodLogResult logged = await ref
          .read(foodLoggingServiceProvider)
          .logParsedItems(items: itemsToLog, mealType: _selectedMealType, dateKey: widget.dateKey);

      if (!mounted) return;
      final MealSlotMeta slot = MealSlotMeta.of(_selectedMealType);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.foodAlimentosAnadidosEn(
                logged.logIds.length.toString(),
                slot.title(context.l10n).toString(),
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(AppIcons.textEntry, color: c.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.comerWriteMeal,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ScFonts.display,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonClose,
                icon: Icon(AppIcons.close, color: c.text2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            context.l10n.foodDescribeTuPlatoOUsa,
            softWrap: true,
            style: TextStyle(fontFamily: ScFonts.ui, fontSize: 12.5, color: c.text2),
          ),

          const SizedBox(height: 12),

          // Sugerencias tocables para inspirar entrada rápida
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _examples(context.l10n).map((String sample) {
              return ActionChip(
                label: Text(sample, style: const TextStyle(fontSize: 11.5)),
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() {
                    _textController.text = sample;
                    _previewItems = null;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _textController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _isListening
                  ? context.l10n.foodTeEscuchoDiLoQue
                  : context.l10n.foodEj200gPechugaDePollo,
              suffixIcon: _speechAvailable
                  ? IconButton(
                      tooltip: _isListening
                          ? context.l10n.foodDetenerDictado
                          : context.l10n.foodDictarSinConexion,
                      onPressed: _toggleDictation,
                      icon: Icon(
                        _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                        color: _isListening ? c.accent : c.text2,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: c.bg3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (_) {
              if (_previewItems != null) {
                setState(() => _previewItems = null);
              }
            },
          ),

          const SizedBox(height: 14),

          Text(
            context.l10n.foodMomentoDeComida,
            style: TextStyle(
              fontFamily: ScFonts.display,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          MealSlotSelectorGrid(
            selectedMealType: _selectedMealType,
            compact: true,
            onSelected: (MealType nextMeal) {
              setState(() => _selectedMealType = nextMeal);
            },
          ),

          if (_previewItems != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              _previewItems!.isEmpty
                  ? context.l10n.foodNoSeDetectaronAlimentosClaros
                  : context.l10n.foodIngredientesDetectados(_previewItems!.length.toString()),
              softWrap: true,
              style: TextStyle(
                fontFamily: ScFonts.display,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _previewItems!.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _previewItems![i].searchTerm,
                        softWrap: true,
                        style: TextStyle(
                          fontFamily: ScFonts.ui,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, size: 19),
                      onPressed: () => _adjustPreviewGrams(i, -25),
                    ),
                    Text(
                      context.l10n.foodG11(NumberFormats.group(_previewItems![i].grams)),
                      style: TextStyle(
                        fontFamily: ScFonts.display,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline, size: 19),
                      onPressed: () => _adjustPreviewGrams(i, 25),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.foodQuitarIngrediente,
                      icon: Icon(AppIcons.delete, size: 17, color: c.text3),
                      onPressed: () {
                        setState(() => _previewItems!.removeAt(i));
                      },
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 16),

          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _analyzeText,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(context.l10n.foodRevisarPorciones),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _confirmAndLog,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.ink,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(AppIcons.check, size: 18),
                  label: Text(
                    _isProcessing ? context.l10n.foodGuardando : context.l10n.todayEntreno5s,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
