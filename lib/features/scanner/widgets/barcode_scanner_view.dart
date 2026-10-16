import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shelf_snap/features/scanner/widgets/aim_box.dart';

class BarcodeScannerView extends StatefulWidget {
  final ValueChanged<String> onIsbn;

  const BarcodeScannerView({super.key, required this.onIsbn});

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  static final _isbn13 = RegExp(r'^97[89]\d{10}$');

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || !_isbn13.hasMatch(code)) {
        debugPrint('[Barcode] ignored: $code');
        continue;
      }
      widget.onIsbn(code);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A wide, short box (barcode-shaped), a bit above centre so the bottom
  /// controls don't cover it.
  static Rect _aimWindow(Size size) {
    final width = (size.width * 0.8).clamp(0.0, 360.0);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.4),
      width: width,
      height: width * 0.45,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final window = _aimWindow(constrains.biggest);
        return MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          scanWindow: window,
          overlayBuilder: (context, _) => AimBox(window: window),
        );
      },
    );
  }
}
