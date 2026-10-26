import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';
import 'package:shelf_snap/features/scanner/providers/barcode_session_provider.dart';
import 'package:shelf_snap/features/scanner/widgets/aim_box.dart';
import 'package:shelf_snap/features/scanner/widgets/barcode_scan_feed.dart';

class BarcodeScannerView extends ConsumerStatefulWidget {
  final ValueChanged<String> onIsbn;

  const BarcodeScannerView({super.key, required this.onIsbn});

  @override
  ConsumerState<BarcodeScannerView> createState() =>
      _BarcodeScannerViewState();
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

  // Short-lived feedback: green outline on a new scan, and the ISBN of a
  // scan that was already in the session
  bool _flashNew = false;
  String? _duplicateIsbn;
  Timer? _flashTimer;
  Timer? _duplicateTimer;

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
      if (existing != null && existing.status != HitStatus.failed) {
        _showDuplicate(code);
      } else {
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

  void _showDuplicate(String isbn) {
    _duplicateTimer?.cancel();
    setState(() => _duplicateIsbn = isbn);
    _duplicateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _duplicateIsbn = null);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _duplicateTimer?.cancel();
    _controller.removeListener(_logState);
    _controller.dispose();
    super.dispose();
  }

  /// A wide, short box (barcode-shaped), a bit above centre so the bottom
  /// controls don't cover it.
  static Rect _aimWindow(Size size) {
    final width = (size.width * 0.8).clamp(0.0, 360.0);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.3),
      width: width,
      height: width * 0.45,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final window = _aimWindow(constraints.biggest);
        final count = ref.watch(barcodeSessionProvider).length;

        return Stack(
          children: [
            // No scanWindow: the whole frame is scanned, the box is a guide
            Positioned.fill(
              child: MobileScanner(controller: _controller, onDetect: _onDetect),
            ),
            AimBox(
              window: window,
              borderColor: _flashNew ? Colors.greenAccent : Colors.white,
            ),

            // Hint under the box, then the live feed of recent scans
            Positioned(
              left: window.left,
              right: constraints.maxWidth - window.right,
              top: window.bottom + 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    count == 0
                        ? 'Point at the barcode on the back cover'
                        : 'Scanned $count ${count == 1 ? 'book' : 'books'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  BarcodeScanFeed(highlightIsbn: _duplicateIsbn),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
