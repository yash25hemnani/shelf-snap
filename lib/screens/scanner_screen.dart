import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/services/book_search_service.dart';
import 'package:shelf_snap/services/match_scoring_service.dart';
import 'package:shelf_snap/services/logger_service.dart';
import 'package:shelf_snap/models/book_result.dart';
import 'package:shelf_snap/widgets/genre_alert_sheet.dart';
import 'package:shelf_snap/widgets/genre_selector.dart';
import 'package:shelf_snap/widgets/scanner_empty_state.dart';
import 'package:shelf_snap/widgets/scanner_sheet_header.dart';
import 'package:shelf_snap/widgets/book_result_card.dart';
import '../models/identified_book.dart';
import '../services/book_identification_service.dart';

/// Live camera scanner: captures a photo of a bookshelf, OCRs it, sends the
/// text to [BookIdentificationService] to resolve individual books, then
/// looks each one up via [BookSearchService] and ranks candidates with
/// [MatchScoringService]. Confirmed matches accumulate in a results sheet
/// the user can keep scanning into.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // ─── Camera ───────────────────────────────────────────

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // ─── Genre alerts ─────────────────────────────────────

  Set<String> _watchedGenres = {};
  void _openGenreAlerts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return GenreAlertSheet(
            watchedGenres: _watchedGenres,
            onChanged: (updated) {
              setState(() => _watchedGenres = updated);
              setModalState(() {});
            },
            onClearAll: () {
              setState(() => _watchedGenres = {});
              setModalState(() {});
            },
          );
        },
      ),
    );
  }
  // ─── Services ─────────────────────────────────────────

  static const _logger = LoggerService('ScannerScreen');
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _bookIdentificationService = BookIdentificationService();
  final _bookSearchService = BookSearchService();
  final _matchScoringService = MatchScoringService();

  // ─── Session state ────────────────────────────────────

  final List<ScoredBookResult> _results = [];
  int _captureCount = 0;
  int _activeProcessingCount = 0;
  static const int _maxConcurrentCaptures = 3;

  // Top match must score at least this well to be kept; weaker matches are
  // shown to the user as noise otherwise, since OCR text is often messy.
  static const double _strongMatchThreshold = 0.6;

  bool get _isProcessing => _activeProcessingCount > 0;

  // ─── Flash ────────────────────────────────────────────

  FlashMode _flashMode = FlashMode.off;

  void _cycleFlashMode() async {
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.torch];
    final next = modes[(modes.indexOf(_flashMode) + 1) % modes.length];
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flashMode = next);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash mode not supported on this device'),
          ),
        );
      }
    }
  }

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.off => Icons.flash_off,
    FlashMode.auto => Icons.flash_auto,
    FlashMode.torch => Icons.flashlight_on,
    _ => Icons.flash_off,
  };

  // ─── Lifecycle ────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _setupCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ─── Camera setup ─────────────────────────────────────

  Future<void> _setupCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) throw Exception('Camera permission not granted');

    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );

    _controller = CameraController(backCamera, ResolutionPreset.high);
    await _controller!.initialize();
  }

  // ─── Debug logging ────────────────────────────────────

  void _logIdentifiedBook(IdentifiedBook book, int index, int total) {
    _logger.debug('[Book $index/$total] "${book.title}" by ${book.author}');
  }

  void _logSearch(String query, List<BookResult> candidates) {
    _logger.debug('  Search: "$query"');
    _logger.debug('  Candidates: ${candidates.length}');
    for (final c in candidates.take(3)) {
      _logger.debug('    - "${c.title}" by ${c.author ?? "?"}');
    }
  }

  void _logScoring(List<ScoredBookResult> scored) {
    for (final s in scored.take(3)) {
      _logger.debug(
        '  ${s.score.toStringAsFixed(2)} | "${s.book.title}"'
        ' [${s.isConfident ? "confident" : "weak"}]',
      );
    }
    if (scored.isEmpty) _logger.debug('  no results');
  }

  void _logResult(
    ScoredBookResult? result, {
    required bool skipped,
    required bool discarded,
  }) {
    if (discarded) {
      _logger.debug('  Discarded: below strong-match threshold');
    } else if (skipped) {
      _logger.debug('  Skipped: already in list');
    } else if (result == null) {
      _logger.debug('  No match found');
    } else {
      _logger.debug(
        '  Added: "${result.book.title}"'
        ' score=${result.score.toStringAsFixed(2)}'
        ' isbn=${result.book.isbn ?? "none"}'
        ' genres=${result.book.genres.isEmpty ? "none" : result.book.genres.join(", ")}'
        ' cover=${result.book.coverUrl != null ? "yes" : "no"}',
      );
    }
  }

  // ─── Capture + process ────────────────────────────────

  Future<void> _captureAndProcess() async {
    // If camera not initialized, return
    if (_controller == null || !_controller!.value.isInitialized) return;

    // If more than 3 pictures processing, show message on snackbar and return
    if (_activeProcessingCount >= _maxConcurrentCaptures) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still processing, please wait a moment...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    // Increase capture count and processing count
    setState(() {
      _activeProcessingCount++;
      _captureCount++;
    });

    try {
      // ── Step 1: Capture ──────────────────────────────
      // Brief delay lets the camera settle (focus/exposure) right after
      // the user taps, avoiding a blurry frame on fast taps.
      await Future.delayed(const Duration(milliseconds: 400));
      final XFile photo = await _controller!.takePicture();
      _logger.debug('\n--- CAPTURE #$_captureCount ---');

      // ── Step 2: OCR ──────────────────────────────────
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      _logger.debug('OCR blocks (raw): ${recognizedText.blocks.length}');

      // ── Step 3: Crop bottom 15% ───────────────────────
      // previewSize is reported in landscape on Android (width = long
      // edge), so in portrait, image height maps to previewSize.width and
      // image width maps to previewSize.height.

      // We are doing this because 15% of screen is hidden by the srollable section
      final imageWidth = _controller!.value.previewSize!.height.round();
      final imageHeight = _controller!.value.previewSize!.width;
      final cutoffY = imageHeight * 0.85;

      // Remove OCR blocks that were in the cut
      final filteredBlocks = recognizedText.blocks
          .where((b) => b.boundingBox.center.dy < cutoffY)
          .toList();
      _logger.debug('OCR blocks (after bottom crop): ${filteredBlocks.length}');

      // ── Step 4: Identify books via Gemini ─────────────
      // Send all the filtered blocks to Gemini, no need for clustering anymore
      final List<IdentifiedBook> identifiedBooks =
          await _bookIdentificationService.identifyBooks(
            filteredBlocks,
            imageWidth,
            imageHeight.round(),
          );
      _logger.debug('Books identified: ${identifiedBooks.length}');

      // ── Step 5: Search + score each identified book ──
      for (int i = 0; i < identifiedBooks.length; i++) {
        final book = identifiedBooks[i];
        _logIdentifiedBook(book, i + 1, identifiedBooks.length);

        final List<BookResult> candidates = await _bookSearchService.search(
          book.searchQuery,
        );
        _logSearch(book.searchQuery, candidates);

        final List<ScoredBookResult> scoredResults = _matchScoringService
            .scoreAndRank(book.searchQuery, candidates);
        _logScoring(scoredResults);

        if (scoredResults.isNotEmpty && mounted) {
          final topMatch = scoredResults.first;

          if (topMatch.score < _strongMatchThreshold) {
            _logResult(null, skipped: false, discarded: true);
          } else {
            setState(() {
              final alreadyAdded = _results.any(
                (r) =>
                    r.book.title.toLowerCase() ==
                    topMatch.book.title.toLowerCase(),
              );

              if (!alreadyAdded) {
                _results.add(topMatch);
                _logResult(topMatch, skipped: false, discarded: false);
              } else {
                _logResult(topMatch, skipped: true, discarded: false);
              }
            });
          }
        } else {
          _logResult(null, skipped: false, discarded: false);
        }
      }

      _logger.debug('--- CAPTURE #$_captureCount END ---\n');
    } catch (e, stackTrace) {
      _logger.error('Capture/process failed', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _activeProcessingCount--);
    }
  }

  // ─── Remove a result ──────────────────────────────────

  void _removeResult(int index) => setState(() => _results.removeAt(index));

  // ─── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              _controller == null ||
              !_controller!.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Positioned.fill(child: CameraPreview(_controller!)),

              Positioned(
                top: 48,
                left: 16,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: BackButtonIcon(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              Positioned(
                top: 48,
                right: 16,
                child: Column(
                  children: [
                    IconButton.filled(
                      onPressed: _cycleFlashMode,
                      icon: Icon(_flashIcon),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    IconButton.filled(
                      onPressed: _openGenreAlerts,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_outlined),
                          if (_watchedGenres.isNotEmpty)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom sheet listing books found so far. Starts mostly
              // collapsed so it doesn't obscure the camera preview, and can
              // be dragged up to review/remove results.
              DraggableScrollableSheet(
                initialChildSize: 0.18,
                minChildSize: 0.18,
                maxChildSize: 0.85,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ScannerSheetHeader(
                          resultCount: _results.length,
                          captureCount: _captureCount,
                          isProcessing: _isProcessing,
                          activeProcessingCount: _activeProcessingCount,
                        ),
                        if (_isProcessing)
                          LinearProgressIndicator(
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        const Divider(height: 1),
                        Expanded(
                          child: _results.isEmpty
                              ? const ScannerEmptyState()
                              : ListView.separated(
                                  controller: scrollController,
                                  itemCount: _results.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) =>
                                      BookResultCard(
                                        result: _results[index],
                                        index: index,
                                        onDismissed: () => _removeResult(index),
                                      ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.18 - 20,
                right: 16,
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: FloatingActionButton(
                    onPressed: _captureAndProcess,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.camera_alt, size: 32),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
