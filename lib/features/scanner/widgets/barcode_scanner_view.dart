import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';
import 'package:shelf_snap/features/scanner/providers/barcode_session_provider.dart';
import 'package:shelf_snap/features/scanner/widgets/aim_box.dart';

class BarcodeScannerView extends ConsumerStatefulWidget {
  final ValueChanged<String> onIsbn;

  const BarcodeScannerView({super.key, required this.onIsbn});

  /// A wide, short box (barcode-shaped) in the upper part of the screen.
  /// The scanner screen also uses it to place the status card below.
  static Rect aimWindow(Size size) {
    final width = (size.width * 0.8).clamp(0.0, 360.0);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.3),
      width: width,
      height: width * 0.45,
    );
  }

  @override
  ConsumerState<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends ConsumerState<BarcodeScannerView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  static final _isbn13 = RegExp(r'^97[89]\d{10}$');
  static const _flashDuration = Duration(milliseconds: 600);

  // Last logged scanner state, so each change is printed once
  bool? _wasRunning;
  MobileScannerException? _lastError;

  // Green outline for a moment after a new scan
  bool _flashNew = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('[Barcode] Scanner view created');
    _controller.addListener(_logState);
  }

  // The controller is a ValueNotifier; this runs on every state change
  void _logState() {
    final state = _controller.value;
    if (state.isRunning != _wasRunning) {
      _wasRunning = state.isRunning;
      debugPrint(
        '[Barcode] Camera ${state.isRunning ? 'running' : 'stopped'}'
        ' (initialized: ${state.isInitialized}, size: ${state.size})',
      );
    }
    if (state.error != null && state.error != _lastError) {
      _lastError = state.error;
      debugPrint(
        '[Barcode] Scanner error: ${state.error!.errorCode} '
        '${state.error!.errorDetails?.message ?? ''}',
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    debugPrint(
      '[Barcode] Detected ${capture.barcodes.length}: '
      '${capture.barcodes.map((b) => '${b.format.name} ${b.rawValue}').join(', ')}',
    );
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || !_isbn13.hasMatch(code)) {
        debugPrint('[Barcode] ignored: $code');
        continue;
      }

      // Failed lookups count as new, since scanning again retries them
      final existing = ref.read(barcodeSessionProvider)[code];
      if (existing == null || existing.status == HitStatus.failed) {
        _flashOutline();
      }
      widget.onIsbn(code);
    }
  }

  void _flashOutline() {
    _flashTimer?.cancel();
    setState(() => _flashNew = true);
    _flashTimer = Timer(_flashDuration, () {
      if (mounted) setState(() => _flashNew = false);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.removeListener(_logState);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final window = BarcodeScannerView.aimWindow(constraints.biggest);

        return Stack(
          children: [
            // No scanWindow: the whole frame is scanned, the box is a guide
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),
            AimBox(
              window: window,
              borderColor: _flashNew ? Colors.greenAccent : Colors.white,
            ),
          ],
        );
      },
    );
  }
}
