import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/shelf_photo_model.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';
import 'package:shelf_snap/features/discover/screens/discovered_screen.dart';
import 'package:shelf_snap/features/discover/sheets/discover_genres_sheet.dart';
import 'package:shelf_snap/features/discover/sheets/discover_results_sheet.dart';
import 'package:shelf_snap/features/discover/sheets/place_sheet.dart';
import 'package:shelf_snap/features/discover/widgets/discover_scan_bar.dart';
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

  // Discover photos still being read, and every book found since the
  // scanner opened, newest scan first, one entry per book
  int _discoverPending = 0;
  List<DiscoveredBookModel> _found = const [];
  // Shelf photos taken since the scanner opened, newest first
  List<ShelfPhotoModel> _photos = const [];

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

  // Reads the shelf with /discover and saves every book to Discovered,
  // tagged with the current place
  Future<void> _captureDiscover() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;
    if (_discoverPending >= ScanSessionNotifier.maxPending) return;

    final messenger = ScaffoldMessenger.of(context);
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (userId == null) {
      messenger.showError('Sign in to use Discover');
      return;
    }
    // Locked at the shutter, so changing the place while this photo is
    // being read doesn't tag these books with the new one
    final place = ref.read(discoverSettingsProvider).valueOrNull?.currentPlace;

    setState(() => _discoverPending++);
    final watch = Stopwatch()..start();

    try {
      final photo = await controller.takePicture();
      final (:books, photo: shelfPhoto) = await ref
          .read(shelfCaptureServiceProvider)
          .discover(photo.path, controller.value.previewSize!);
      debugPrint(
        '[Discover] Capture done in ${watch.elapsedMilliseconds} ms, '
        '${books.length} books',
      );

      // Not awaited: the batch applies locally at once and would hang
      // offline until the connection comes back
      if (books.isNotEmpty) {
        unawaited(
          ref
              .read(discoverRepositoryProvider)
              .saveScan(userId, books, place: place)
              .catchError((Object e) {
                debugPrint('saveScan failed: $e');
                messenger.showError("Couldn't save the books you found");
              }),
        );
      }
      if (!mounted) return;

      if (books.isEmpty) {
        HapticFeedback.heavyImpact();
        messenger.showMessage('No books found. Try again closer to the shelf.');
        return;
      }
      HapticFeedback.mediumImpact();
      final ids = {for (final b in books) b.id};
      setState(() {
        _found = [...books, ..._found.where((b) => !ids.contains(b.id))];
        if (shelfPhoto != null) _photos = [shelfPhoto, ..._photos];
      });
    } catch (e) {
      debugPrint('Discover capture failed: $e');
      // DiscoverService throws readable messages
      messenger.showError('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _discoverPending--);
    }
  }

  void _openDiscovered() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoveredScreen()),
    );
  }

  void _showResults() {
    if (_mode == ScanMode.discover) {
      DiscoverResultsSheet.show(
        context,
        books: _found,
        photos: _photos,
        onRemoved: (book) {
          if (!mounted) return;
          setState(() {
            _found = _found.where((b) => b.id != book.id).toList();
          });
        },
      );
      return;
    }
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
    final isDiscover = _mode == ScanMode.discover;
    // Only watched in Discover mode, so Add mode doesn't read the doc
    final settings = isDiscover
        ? ref.watch(discoverSettingsProvider).valueOrNull ??
              const DiscoverSettingsModel()
        : null;
    // The books the results sheet lists
    final count = isDiscover
        ? _found.length
        : isShelf
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
                      if (isDiscover)
                        IconButton(
                          onPressed: _openDiscovered,
                          tooltip: 'Discovered',
                          icon: const Icon(Icons.collections_bookmark_outlined),
                          color: Colors.white,
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                  if (settings != null) ...[
                    const SizedBox(height: 8),
                    DiscoverScanBar(
                      settings: settings,
                      onGenres: () =>
                          showDiscoverGenresSheet(context, ref, settings),
                      onPlace: () =>
                          PlaceSheet.show(context, settings: settings),
                    ),
                  ],
                  // Discover reads shelf photos with ML Kit, which has no
                  // web version
                  if (isDiscover && kIsWeb)
                    const Expanded(child: Center(child: _DiscoverWebNote()))
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
                            pending: isDiscover
                                ? _discoverPending
                                : session.pending,
                            maxPending: ScanSessionNotifier.maxPending,
                            onPressed: isDiscover
                                ? _captureDiscover
                                : _captureShelf,
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

// Shown in Discover mode on the web, where shelf photos can't be read
class _DiscoverWebNote extends StatelessWidget {
  const _DiscoverWebNote();

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
          const Icon(
            Icons.phone_android_rounded,
            size: 40,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'Discover needs the Android app',
            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Shelf photos can only be read on a phone. Your discovered books '
            'are still here.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
