import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/system_permissions.dart';
import '../../../../core/services/nutrition_label_ocr_service.dart';
import '../../../../core/services/open_food_facts_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import '../../../../shared/theme/sc_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import 'custom_food_sheet.dart';
import 'food_detail_sheet.dart';
import 'meal_slot_selector.dart';

/// Subpágina de cámara en vivo para lectura de códigos EAN-13 / UPC.
///
/// Resuelve primero en SQLite local (0 ms), luego en Open Food Facts y,
/// si no existe o no hay conexión, ofrece alta guiada offline.
class BarcodeScannerSheet extends ConsumerStatefulWidget {
  const BarcodeScannerSheet({
    super.key,
    required this.initialMealType,
    required this.targetDateKey,
  });

  final MealType initialMealType;
  final String targetDateKey;

  @override
  ConsumerState<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends ConsumerState<BarcodeScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  bool _isResolving = false;
  String? _statusMessage;

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  Future<void> _handleDetectedCode(String rawCode) async {
    if (_isResolving) return;
    final String cleanCode = rawCode.trim();
    if (cleanCode.length < 6) return;

    setState(() {
      _isResolving = true;
      _statusMessage = context.l10n.foodBuscandoEnCatalogoLocalY((cleanCode).toString());
    });

    unawaited(HapticFeedback.mediumImpact());
    await _scannerController.stop();

    try {
      final OpenFoodFactsService offService = ref.read(openFoodFactsServiceProvider);
      final FoodItem? food = await offService.resolveBarcode(cleanCode);

      if (!mounted) return;

      if (food != null) {
        Navigator.of(context).pop();
        await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FoodDetailSheet(
            food: food,
            initialMealType: widget.initialMealType,
            targetDateKey: widget.targetDateKey,
          ),
        );
      } else {
        setState(() {
          _isResolving = false;
          _statusMessage = null;
        });

        final bool? createCustom = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) {
            final ScColors dialogColors = ctx.sc;
            return AlertDialog(
              backgroundColor: dialogColors.bg2,
              title: Text(context.l10n.foodProductoNoRegistrado),
              content: Text(context.l10n.foodElCodigoAunNoFigura((cleanCode).toString())),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(context.l10n.foodSeguirEscaneando),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(context.l10n.comerCreateFood),
                ),
              ],
            );
          },
        );

        if (!mounted) return;
        if (createCustom == true) {
          await _openCustomFoodWithCode(cleanCode);
        } else {
          await _scannerController.start();
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _statusMessage = context.l10n.foodSinConexionOTiempoAgotado;
      });
      await _scannerController.start();
    }
  }

  Future<void> _openCustomFoodWithCode([String? code]) async {
    await _scannerController.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
    final FoodItem? created = await showModalBottomSheet<FoodItem>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomFoodSheet(initialBarcode: code),
    );
    if (created != null && mounted) {
      await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FoodDetailSheet(
          food: created,
          initialMealType: widget.initialMealType,
          targetDateKey: widget.targetDateKey,
        ),
      );
    }
  }

  Future<void> _scanTableWithOcr() async {
    await _scannerController.stop();
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 92);
      if (photo == null) {
        await _scannerController.start();
        return;
      }

      if (!mounted) return;
      final OcrNutritionData data = await ref
          .read(nutritionLabelOcrServiceProvider)
          .processImage(photo);

      if (!mounted) return;
      Navigator.of(context).pop();
      final FoodItem? created = await showModalBottomSheet<FoodItem>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CustomFoodSheet(initialOcrData: data),
      );
      if (created != null && mounted) {
        await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FoodDetailSheet(
            food: created,
            initialMealType: widget.initialMealType,
            targetDateKey: widget.targetDateKey,
          ),
        );
      }
    } catch (_) {
      if (mounted) await _scannerController.start();
    }
  }

  Future<void> _promptManualBarcode() async {
    final String? entered = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualBarcodeDialog(),
    );

    if (entered != null && entered.isNotEmpty) {
      await _handleDetectedCode(entered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    final MealSlotMeta slot = MealSlotMeta.of(widget.initialMealType);

    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: c.isFlat ? Border(top: BorderSide(color: c.line2, width: 1.5)) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _scannerController,
            errorBuilder: (BuildContext context, MobileScannerException error) => _CameraUnavailable(
              permissionDenied: error.errorCode == MobileScannerErrorCode.permissionDenied,
              onOpenSettings: () => unawaited(ref.read(systemPermissionsProvider).openAppSettings()),
            ),
            onDetect: (BarcodeCapture capture) {
              for (final Barcode barcode in capture.barcodes) {
                final String? raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  unawaited(_handleDetectedCode(raw));
                  break;
                }
              }
            },
          ),

          // Retícula central con esquinas de alto contraste (cero sombras difusas)
          Center(
            child: SizedBox(
              width: 268,
              height: 168,
              child: CustomPaint(
                painter: _ReticleCornerPainter(color: _isResolving ? c.warning : c.accent),
              ),
            ),
          ),

          // Barra HUD superior
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.bg2.withValues(alpha: c.isFlat ? 1.0 : 0.92),
                borderRadius: BorderRadius.circular(18),
                border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
              ),
              child: Row(
                children: <Widget>[
                  Icon(AppIcons.barcode, color: c.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          context.l10n.foodEscanerEan13,
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: ScFonts.display,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        Text(
                          context.l10n.foodDestino(slot.title(context.l10n).toString()),
                          softWrap: true,
                          style: TextStyle(fontFamily: ScFonts.ui, fontSize: 11.5, color: c.text2),
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _scannerController,
                    builder: (BuildContext context, MobileScannerState state, Widget? child) {
                      final bool isFrontCamera = state.cameraDirection == CameraFacing.front;
                      final bool isTorchOn = state.torchState == TorchState.on;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (!isFrontCamera)
                            IconButton(
                              tooltip: context.l10n.foodLinterna,
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                await _scannerController.toggleTorch();
                              },
                              icon: Icon(
                                isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: isTorchOn ? c.carbs : c.text,
                              ),
                            ),
                          IconButton(
                            tooltip: context.l10n.foodCambiarCamara,
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              await _scannerController.switchCamera();
                            },
                            icon: Icon(Icons.cameraswitch_rounded, color: c.text),
                          ),
                          IconButton(
                            tooltip: context.l10n.commonClose,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(AppIcons.close, color: c.text),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Tarjeta inferior de estado y controles alternativos
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.bg2.withValues(alpha: c.isFlat ? 1.0 : 0.95),
                  borderRadius: BorderRadius.circular(22),
                  border: c.isFlat ? Border.all(color: c.line2, width: 1.5) : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_isResolving)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent),
                        ),
                      ),
                    Text(
                      _statusMessage ?? context.l10n.foodEnfocaElCodigoDeBarras,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: ScFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isResolving ? null : _promptManualBarcode,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.dialpad_rounded, size: 18),
                            label: Text(context.l10n.foodEscribirEan),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isResolving ? null : _openCustomFoodWithCode,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(AppIcons.add, size: 18),
                            label: Text(context.l10n.foodCrearManual),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isResolving ? null : _scanTableWithOcr,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: c.isFlat ? c.line2 : c.accent),
                        ),
                        icon: Icon(Icons.document_scanner_rounded, size: 18, color: c.accent),
                        label: Text(
                          context.l10n.foodEscanearTablaNutricionalOcr,
                          style: TextStyle(
                            fontFamily: ScFonts.ui,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticleCornerPainter extends CustomPainter {
  const _ReticleCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const double corner = 28.0;
    final double w = size.width;
    final double h = size.height;

    final Path path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, 0)
      ..lineTo(corner, 0)
      ..moveTo(w - corner, 0)
      ..lineTo(w, 0)
      ..lineTo(w, corner)
      ..moveTo(0, h - corner)
      ..lineTo(0, h)
      ..lineTo(corner, h)
      ..moveTo(w - corner, h)
      ..lineTo(w, h)
      ..lineTo(w, h - corner);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReticleCornerPainter oldDelegate) => oldDelegate.color != color;
}

class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();

  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;
    return AlertDialog(
      backgroundColor: c.bg2,
      title: Text(context.l10n.foodEscribirCodigoEanUpc),
      content: TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(
          hintText: context.l10n.foodEj8480000123456,
          filled: true,
          fillColor: c.bg3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onSubmitted: (String val) {
          if (val.trim().length >= 6) {
            Navigator.of(context).pop(val.trim());
          }
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final String code = _codeCtrl.text.trim();
            if (code.length >= 6) {
              Navigator.of(context).pop(code);
            }
          },
          child: Text(context.l10n.foodBuscar),
        ),
      ],
    );
  }
}

/// Cámara no disponible: sin permiso (con acceso a Ajustes) u otro fallo. Los
/// botones de abajo siguen permitiendo escribir el código o leer la etiqueta.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.permissionDenied, required this.onOpenSettings});

  final bool permissionDenied;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              Text(
                permissionDenied ? l10n.scanCameraDeniedTitle : l10n.scanCameraErrorTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                permissionDenied ? l10n.scanCameraDeniedBody : l10n.scanCameraErrorBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14, height: 1.35),
              ),
              if (permissionDenied) ...<Widget>[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(l10n.scanOpenSettings),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
