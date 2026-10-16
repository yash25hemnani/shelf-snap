import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shelf_snap/features/scanner/models/scan_mode.dart';
import 'package:shelf_snap/features/scanner/providers/scan_session_provider.dart';
import 'package:shelf_snap/features/scanner/widgets/barcode_scanner_view.dart';
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
  ScanInput _input = ScanInput.shelf;
  final _scannedIsbns = <String>{};

  void _setMode(ScanMode mode) {
    setState(() {
      _mode = mode;
    });

    if (mode == ScanMode.discover) _setInput(ScanInput.shelf);
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
    if (!_scannedIsbns.add(isbn)) {
      debugPrint('[Barcode] duplicate: $isbn');
      return;
    }
    debugPrint('[Barcode] new: $isbn, looking up...');

    try {
      final book = await ref.read(bookSearchServiceProvider).lookupIsbn(isbn);
      if (book == null) {
        debugPrint('[Barcode] not found: $isbn');
      } else {
        debugPrint('[Barcode] found: ${book.title} by ${book.author}');
      }
    } catch (e) {
      _scannedIsbns.remove(isbn); // let a rescan try again
      debugPrint('[Barcode] lookup failed for $isbn: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraFuture = _setupCamera();
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

    if (ref.read(scanSessionProvider).pending >= ScanSessionNotifier.maxPending)
      return;

    notifier.startProcessing();

    try {
      final photo = await controller.takePicture();
      final results = await ref
          .read(shelfCaptureServiceProvider)
          .identify(photo.path, controller.value.previewSize!);

      if (!mounted) return;
      notifier.addResults(results);
    } catch (e) {
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
      builder: (_) => const ScanResultsSheet(),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanSessionProvider);
    ref.watch(
      shelfCaptureServiceProvider,
    ); // keep the OCR service alive while the screen is open

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -200 && session.results.isNotEmpty) _showResults();
        },
        child: Stack(
          children: [
            if (_input == ScanInput.barcode)
              Positioned.fill(child: BarcodeScannerView(onIsbn: _onIsbn,))
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
                  const Spacer(),
                  if (_mode == ScanMode.add)
                    ScanInputToggle(input: _input, onChanged: _setInput),

                  if (_input == ScanInput.shelf) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Spacer(),
                        ShutterButton(
                          pending: session.pending,
                          maxPending: ScanSessionNotifier.maxPending,
                          onPressed: _captureShelf,
                        ),
                        Expanded(
                          child: Center(
                            child: ScanCountBadge(
                              count: session.results.length,
                              onTap: session.results.isEmpty
                                  ? null
                                  : _showResults,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
