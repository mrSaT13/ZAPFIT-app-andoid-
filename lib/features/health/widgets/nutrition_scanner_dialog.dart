import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen barcode scanner. Returns the raw barcode string when a code
/// was captured, `null` when the user closed the dialog.
///
/// Camera permission is requested by mobile_scanner itself when the
/// preview starts; failures surface in the error builder with a retry.
Future<String?> showNutritionBarcodeScanner(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black,
    builder: (dialogContext) => const _NutritionBarcodeScannerDialog(),
  );
}

class _NutritionBarcodeScannerDialog extends StatefulWidget {
  const _NutritionBarcodeScannerDialog();

  @override
  State<_NutritionBarcodeScannerDialog> createState() =>
      _NutritionBarcodeScannerDialogState();
}

class _NutritionBarcodeScannerDialogState
    extends State<_NutritionBarcodeScannerDialog> {
  late final MobileScannerController _controller;
  bool _handled = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      // Product barcodes only — keeps detection fast and avoids QR noise.
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.itf14,
      ],
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (e) {
      debugPrint('NutritionScanner: torch toggle error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Сканер штрихкода'),
        actions: [
          IconButton(
            tooltip: 'Фонарик',
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_outlined,
                      color: Colors.white70, size: 48,),
                  const SizedBox(height: 12),
                  const Text(
                    'Нет доступа к камере.\nРазрешите камеру в настройках системы.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Закрыть'),
                  ),
                  Text(error.errorCode.name,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
