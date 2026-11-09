import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/services/discover_service.dart';
import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';
import 'package:shelf_snap/features/scanner/services/book_identification_service.dart';

class ShelfCaptureService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _identifier = BookIdentificationService();
  final _discover = DiscoverService();

  Future<RecognizedText> _ocr(String photoPath, Size previewSize) async {
    final ocrWatch = Stopwatch()..start();
    final ocr = await _recognizer.processImage(
      InputImage.fromFilePath(photoPath),
    );
    debugPrint(
      '[OCR] ${ocr.blocks.length} blocks in ${ocrWatch.elapsedMilliseconds} ms'
      ' (preview ${previewSize.width.round()}x${previewSize.height.round()})',
    );
    for (final block in ocr.blocks) {
      debugPrint('[OCR]   "${block.text.replaceAll('\n', ' ')}"');
    }
    return ocr;
  }

  Future<List<ScoredBookResult>> identify(
    String photoPath,
    Size previewSize,
  ) async {
    final ocr = await _ocr(photoPath, previewSize);

    // previewSize is landscape on Android, so swap for portrait
    return _identifier.identifyBooks(
      photoPath,
      ocr.blocks,
      previewSize.height.round(),
      previewSize.width.round(),
    );
  }

  // Same OCR hints as identify, sent to /discover. Throws on failure.
  Future<List<DiscoveredBookModel>> discover(
    String photoPath,
    Size previewSize,
  ) async {
    final ocr = await _ocr(photoPath, previewSize);

    return _discover.discoverBooks(
      photoPath,
      ocr.blocks,
      previewSize.height.round(),
      previewSize.width.round(),
    );
  }

  Future<void> close() => _recognizer.close();
}
