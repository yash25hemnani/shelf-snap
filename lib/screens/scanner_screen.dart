import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/services/book_search_service.dart';
import 'package:shelf_snap/services/match_scoring_service.dart';
import 'package:shelf_snap/models/book_result.dart';
import 'package:shelf_snap/widgets/confidence_badge.dart';
import 'package:shelf_snap/widgets/book_cover_placeholder.dart';
import 'package:shelf_snap/widgets/scanner_empty_state.dart';
import '../models/identified_book.dart';
import '../services/book_identification_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // ─── Camera ───────────────────────────────────────────

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  // ─── Services ─────────────────────────────────────────

  final _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);
  final _bookIdentificationService = BookIdentificationService();
  final _bookSearchService = BookSearchService();
  final _matchScoringService = MatchScoringService();

  // ─── Session state ────────────────────────────────────

  final List<ScoredBookResult> _results = [];
  int _captureCount = 0;
  int _activeProcessingCount = 0;
  static const int _maxConcurrentCaptures = 3;
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
              content: Text('Flash mode not supported on this device')),
        );
      }
    }
  }

  IconData get _flashIcon =>
      switch (_flashMode) {
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
            (c) => c.lensDirection == CameraLensDirection.back);

    _controller = CameraController(backCamera, ResolutionPreset.high);
    await _controller!.initialize();
  }

  // ─── Debug logging ────────────────────────────────────

  void _logIdentifiedBook(IdentifiedBook book, int index, int total) {
    print('[Book $index/$total] "${book.title}" by ${book.author}');
  }

  void _logSearch(String query, List<BookResult> candidates) {
    print('  Search: "$query"');
    print('  Candidates: ${candidates.length}');
    for (final c in candidates.take(3)) {
      print('    - "${c.title}" by ${c.author ?? "?"}');
    }
  }

  void _logScoring(List<ScoredBookResult> scored) {
    for (final s in scored.take(3)) {
      print('  ${s.score.toStringAsFixed(2)} | "${s.book.title}"'
          ' [${s.isConfident ? "confident" : "weak"}]');
    }
    if (scored.isEmpty) print('  no results');
  }

  void _logResult(ScoredBookResult? result, {required bool skipped, required bool discarded}) {
    if (discarded) {
      print('  Discarded: below strong-match threshold');
    } else if (skipped) {
      print('  Skipped: already in list');
    } else if (result == null) {
      print('  No match found');
    } else {
      print('  Added: "${result.book.title}"'
          ' score=${result.score.toStringAsFixed(2)}'
          ' isbn=${result.book.isbn ?? "none"}'
          ' genres=${result.book.genres.isEmpty ? "none" : result.book.genres
          .join(", ")}'
          ' cover=${result.book.coverUrl != null ? "yes" : "no"}');
    }
  }

  // ─── Capture + process ────────────────────────────────

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

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

    setState(() {
      _activeProcessingCount++;
      _captureCount++;
    });

    try {
      // ── Step 1: Capture ──────────────────────────────
      await Future.delayed(const Duration(milliseconds: 400));
      final XFile photo = await _controller!.takePicture();
      print('\n--- CAPTURE #$_captureCount ---');

      // ── Step 2: OCR ──────────────────────────────────
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      print('OCR blocks (raw): ${recognizedText.blocks.length}');

      // ── Step 3: Crop bottom 15% ───────────────────────
      // previewSize is reported in landscape on Android (width = long
      // edge), so in portrait, image height maps to previewSize.width and
      // image width maps to previewSize.height.
      final imageWidth = _controller!.value.previewSize!.height.round();
      final imageHeight = _controller!.value.previewSize!.width;
      final cutoffY = imageHeight * 0.85;

      final filteredBlocks = recognizedText.blocks
          .where((b) => b.boundingBox.center.dy < cutoffY)
          .toList();
      print('OCR blocks (after bottom crop): ${filteredBlocks.length}');

      // ── Step 4: Identify books via Gemini ─────────────
      final List<IdentifiedBook> identifiedBooks =
      await _bookIdentificationService.identifyBooks(
        filteredBlocks,
        imageWidth,
        imageHeight.round(),
      );
      print('Books identified: ${identifiedBooks.length}');

      // ── Step 5: Search + score each identified book ──
      for (int i = 0; i < identifiedBooks.length; i++) {
        final book = identifiedBooks[i];
        _logIdentifiedBook(book, i + 1, identifiedBooks.length);

        final List<BookResult> candidates =
        await _bookSearchService.search(book.searchQuery);
        _logSearch(book.searchQuery, candidates);

        final List<ScoredBookResult> scoredResults =
        _matchScoringService.scoreAndRank(book.searchQuery, candidates);
        _logScoring(scoredResults);

        if (scoredResults.isNotEmpty && mounted) {
          final topMatch = scoredResults.first;

          if (topMatch.score < _strongMatchThreshold) {
            _logResult(null, skipped: false, discarded: true);
          } else {
            setState(() {
              final alreadyAdded = _results.any((r) =>
              r.book.title.toLowerCase() ==
                  topMatch.book.title.toLowerCase());

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

      print('--- CAPTURE #$_captureCount END ---\n');
    } catch (e, stackTrace) {
      print('ERROR: $e');
      print(stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _activeProcessingCount--);
    }
  }

  // ─── Remove a result ──────────────────────────────────

  void _removeResult(int index) =>
      setState(() => _results.removeAt(index));

  // ─── Sheet header ─────────────────────────────────────

  Widget _buildSheetHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_results.length} book${_results.length == 1 ? '' : 's'} found',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            if (_captureCount > 0)
              Text(
                '$_captureCount photo${_captureCount == 1 ? '' : 's'} scanned',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                    color: Colors.grey[500]),
              ),
          ],
        ),
        if (_isProcessing) ...[
          const SizedBox(height: 6),
          Row(children: [
            SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Theme
                    .of(context)
                    .colorScheme
                    .primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _activeProcessingCount == 1
                  ? 'Processing 1 capture...'
                  : 'Processing $_activeProcessingCount captures...',
              style: TextStyle(
                color: Theme
                    .of(context)
                    .colorScheme
                    .primary,
                fontSize: 12,
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  // ─── Book card ────────────────────────────────────────

  Widget _buildBookCard(ScoredBookResult result, int index) {
    final book = result.book;
    return Dismissible(
      key: ValueKey('${book.title}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeResult(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red[900],
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        dense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: book.coverUrl != null
              ? Image.network(
            book.coverUrl!,
            width: 36, height: 50, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const BookCoverPlaceholder(),
          )
              : const BookCoverPlaceholder(),
        ),
        title: Text(
          book.title,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          book.author ?? 'Unknown author',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 70),
          child: ConfidenceBadge(score: result.score),
        ),
      ),
    );
  }

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

          return Stack(children: [
            Positioned.fill(child: CameraPreview(_controller!)),

            Positioned(
              top: 48, right: 16,
              child: IconButton.filled(
                onPressed: _cycleFlashMode,
                icon: Icon(_flashIcon),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            DraggableScrollableSheet(
              initialChildSize: 0.18,
              minChildSize: 0.18,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme
                        .of(context)
                        .colorScheme
                        .surface,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(children: [
                    _buildSheetHeader(),
                    if (_isProcessing)
                      LinearProgressIndicator(
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme
                              .of(context)
                              .colorScheme
                              .primary,
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
                            _buildBookCard(_results[index], index),
                      ),
                    ),
                  ]),
                );
              },
            ),

            Positioned(
              bottom: 120, right: 16,
              child: FloatingActionButton.large(
                onPressed: _captureAndProcess,
                backgroundColor:
                Theme
                    .of(context)
                    .colorScheme
                    .primary,
                child: const Icon(Icons.camera_alt, size: 32),
              ),
            ),
          ]);
        },
      ),
    );
  }
}