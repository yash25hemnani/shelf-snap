import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';
import 'package:shelf_snap/features/scanner/services/book_identification_service.dart';

class ShelfCaptureService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _identifier = BookIdentificationService();

  Future<List<ScoredBookResult>> identify(
    String photoPath,
    Size previewSize,
  ) async {
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

    // previewSize is landscape on Android, so swap for portrait
    return _identifier.identifyBooks(
      photoPath,
      ocr.blocks,
      previewSize.height.round(),
      previewSize.width.round(),
    );
  }

  Future<void> close() => _recognizer.close();
}
