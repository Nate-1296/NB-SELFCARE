import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/open_food_facts_service.dart';
import '../../../../shared/theme/sc_colors.dart';
import 'food_detail_sheet.dart';

/// Escáner de código de barras con vista de cámara en tiempo real mediante `mobile_scanner`.
/// Detecta códigos EAN-13/UPC y abre de inmediato la ficha nutricional (FoodDetailSheet).
class BarcodeScannerSheet extends ConsumerStatefulWidget {
  const BarcodeScannerSheet({
    super.key,
    required this.dateKey,
    this.mealType = 'lunch',
  });

  final String dateKey;
  final String mealType;

  static Future<bool?> show({
    required BuildContext context,
    required String dateKey,
    String mealType = 'lunch',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerSheet(dateKey: dateKey, mealType: mealType),
    );
  }

  @override
  ConsumerState<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends ConsumerState<BarcodeScannerSheet> {
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusText = 'Buscando código $code...';
    });

    await HapticFeedback.mediumImpact();

    final off = ref.read(openFoodFactsServiceProvider);
    final FoodItem? food = await off.resolveBarcode(code);

    if (!mounted) return;

    if (food != null) {
      Navigator.of(context).pop();
      // Abrir ficha detallada del alimento para ajustar gramos
      unawaited(
        FoodDetailSheet.show(
          context: context,
          foodItem: food,
          dateKey: widget.dateKey,
          initialMealType: widget.mealType,
        ),
      );
    } else {
      setState(() {
        _isProcessing = false;
        _statusText = 'Código $code no encontrado. Prueba ingresarlo a mano.';
      });
    }
  }

  void _showManualInputDialog() {
    final textCtrl = TextEditingController();
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingresar Código EAN-13'),
        content: TextField(
          controller: textCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Código de barras',
            hintText: 'Ej. 7702001041400',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final code = textCtrl.text.trim();
              if (code.isNotEmpty) {
                Navigator.of(ctx).pop();
                unawaited(_handleBarcode(code));
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ScColors c = context.sc;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Stack(
          children: [
            // Vista de Cámara
            MobileScanner(
              controller: _scannerController,
              onDetect: (BarcodeCapture capture) {
                if (_isProcessing) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    unawaited(_handleBarcode(raw));
                    break;
                  }
                }
              },
            ),

            // Marco Guía / Visor Central
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isProcessing ? Colors.amber : c.accent,
                    width: 3.0,
                  ),
                ),
              ),
            ),

            // Barra Superior de Controles
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: _isTorchOn ? Colors.amber : Colors.white,
                          ),
                          onPressed: () async {
                            await _scannerController.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                          onPressed: () => unawaited(_scannerController.switchCamera()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Barra Inferior con Estado y Botón Manual
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_statusText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _statusText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Escribir código a mano'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
