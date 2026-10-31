import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';
import 'package:shelf_snap/features/scanner/models/scan_mode.dart';
import 'package:shelf_snap/features/scanner/providers/barcode_session_provider.dart';
import 'package:shelf_snap/features/scanner/providers/scan_session_provider.dart';
import 'package:shelf_snap/features/scanner/widgets/barcode_scanner_view.dart';
import 'package:shelf_snap/features/scanner/widgets/barcode_sheet.dart';
import 'package:shelf_snap/features/scanner/widgets/barcode_status_card.dart';
import 'package:shelf_snap/features/scanner/widgets/scan_count_badge.dart';
import 'package:shelf_snap/features/scanner/widgets/scan_input_toggle.dart';
import 'package:shelf_snap/features/scanner/widgets/scan_mode_toggle.dart';
import 'package:shelf_snap/features/scanner/widgets/scan_results_sheet.dart';
import 'package:shelf_snap/features/scanner/widgets/scanner_camera_view.dart';
import 'package:shelf_snap/features/scanner/widgets/shutter_button.dart';
import 'package:shelf_snap/features/search/providers/search_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  CameraController? _controller;
  late Future<CameraController> _cameraFuture;

  ScanMode _mode = ScanMode.add;
  // Shelf scan uses ML Kit, which has no web version
  ScanInput _input = kIsWeb ? ScanInput.barcode : ScanInput.shelf;

  // ISBN scanned again, highlighted in the status card for a moment
  String? _duplicateIsbn;
  Timer? _duplicateTimer;

  void _showDuplicate(String isbn) {
    _duplicateTimer?.cancel();
    setState(() => _duplicateIsbn = isbn);
    _duplicateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _duplicateIsbn = null);
    });
  }

  void _setMode(ScanMode mode) {
    setState(() {
      _mode = mode;
    });

    if (mode == ScanMode.discover && !kIsWeb) _setInput(ScanInput.shelf);
  }

  Future<void> _setInput(ScanInput input) async {
    if (input == _input) return;

    if (input == ScanInput.barcode) {
      final controller = _controller;
      _controller = null;
      await controller
          ?.dispose(); // free the camera before mobile scanner opens it
      if (!mounted) return;
      setState(() {
        _input = input;
      });
    } else {
      setState(() {
        _input = input;
        _cameraFuture = _setupCamera();
      });
    }
  }

  Future<void> _onIsbn(String isbn) async {
    final notifier = ref.read(barcodeSessionProvider.notifier);

    if (!notifier.add(isbn)) {
      debugPrint('[Barcode] $isbn already in session, ignored');
      HapticFeedback.lightImpact(); // already in this session
      _showDuplicate(isbn);
      return;
    }

    HapticFeedback.mediumImpact(); // new barcode
    debugPrint('[Barcode] $isbn scanned, looking up');
    final watch = Stopwatch()..start();

    try {
      final book = await ref.read(bookSearchServiceProvider).lookupIsbn(isbn);
      debugPrint(
        book == null
            ? '[Barcode] $isbn no match (${watch.elapsedMilliseconds} ms)'
            : '[Barcode] $isbn -> "${book.title}" '
                  '(${watch.elapsedMilliseconds} ms)',
      );
      if (!mounted) return;
      if (book == null) HapticFeedback.heavyImpact(); // no match for the ISBN
      notifier.resolve(isbn, book);
    } catch (e) {
      debugPrint(
        '[Barcode] $isbn lookup failed (${watch.elapsedMilliseconds} ms): $e',
      );
      if (!mounted) return;
      notifier.fail(isbn); // shown in the feed; a rescan retries it
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _cameraFuture = _setupCamera();
  }

  Future<CameraController> _setupCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) throw Exception('Camera permission not granted');

    final cameras = await availableCameras();

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );

    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;
    await controller.initialize();

    return controller;
  }

  Future<void> _captureShelf() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;

    final notifier = ref.read(scanSessionProvider.notifier);

    if (ref.read(scanSessionProvider).pending >=
        ScanSessionNotifier.maxPending) {
      debugPrint('[Scan] Shutter ignored, too many captures in flight');
      return;
    }

    notifier.startProcessing();
    final watch = Stopwatch()..start();
    debugPrint('[Scan] Capture started');

    try {
      final photo = await controller.takePicture();
      debugPrint('[Scan] Photo taken in ${watch.elapsedMilliseconds} ms');

      final results = await ref
          .read(shelfCaptureServiceProvider)
          .identify(photo.path, controller.value.previewSize!);

      debugPrint(
        '[Scan] Capture done in ${watch.elapsedMilliseconds} ms, '
        '${results.length} books',
      );
      if (!mounted) return;
      notifier.addResults(results);
    } catch (e) {
      debugPrint(
        '[Scan] Capture failed after ${watch.elapsedMilliseconds} ms: $e',
      );
      if (!mounted) return;
      notifier.failProcessing();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    }
  }

  void _showResults() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _input == ScanInput.barcode
          ? const BarcodeSheet()
          : const ScanResultsSheet(),
    );
  }

  @override
  void dispose() {
    _duplicateTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // Space between the top bar and the status card, so the card starts
  // 16px below the aim box. The top bar is one icon button high.
  double _cardGap(BuildContext context) {
    final window = BarcodeScannerView.aimWindow(MediaQuery.sizeOf(context));
    final top = MediaQuery.paddingOf(context).top + kMinInteractiveDimension;
    return (window.bottom + 16 - top).clamp(0.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    final hits = ref.watch(barcodeSessionProvider);
    final isShelf = _input == ScanInput.shelf;
    // Books ready to save, the same ones the results sheet lists
    final count = isShelf
        ? session.results.length
        : hits.values.where((h) => h.status == HitStatus.found).length;

    // keep the OCR service alive while the screen is open
    if (!kIsWeb) ref.watch(shelfCaptureServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200 && count > 0) _showResults();
        },
        child: Stack(
          children: [
            if (_input == ScanInput.barcode)
              Positioned.fill(child: BarcodeScannerView(onIsbn: _onIsbn))
            else
              ScannerCameraView(camera: _cameraFuture),

            SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                      ),
                      Expanded(
                        child: Center(
                          child: ScanModeToggle(
                            mode: _mode,
                            onChanged: _setMode,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  // Discover isn't built yet: a note instead of the controls
                  if (_mode == ScanMode.discover)
                    const Expanded(child: Center(child: _UnderConstruction()))
                  else ...[
                    // Status card from just below the aim box down to the toggle
                    if (isShelf)
                      const Spacer()
                    else ...[
                      SizedBox(height: _cardGap(context)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: BarcodeStatusCard(
                            highlightIsbn: _duplicateIsbn,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_mode == ScanMode.add && !kIsWeb)
                      ScanInputToggle(input: _input, onChanged: _setInput),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Spacer(),
                        if (isShelf)
                          ShutterButton(
                            pending: session.pending,
                            maxPending: ScanSessionNotifier.maxPending,
                            onPressed: _captureShelf,
                          )
                        else
                          const SizedBox(
                            width: 88,
                          ), // same width as the shutter, keeps the badge in place
                        Expanded(
                          child: Center(
                            child: ScanCountBadge(
                              count: count,
                              onTap: count == 0 ? null : _showResults,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shown in Discover mode until the feature exists
class _UnderConstruction extends StatelessWidget {
  const _UnderConstruction();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_rounded, size: 40, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            'Under construction',
            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Point at a shelf to find books you might like. Coming soon.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
