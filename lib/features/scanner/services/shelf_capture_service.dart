import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/shelf_photo_model.dart';
import 'package:shelf_snap/features/discover/services/discover_service.dart';
import 'package:shelf_snap/features/discover/services/shelf_photo_store.dart';
import 'package:shelf_snap/features/discover/services/spine_outliner.dart';
import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';
import 'package:shelf_snap/features/scanner/services/book_identification_service.dart';

class ShelfCaptureService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _identifier = BookIdentificationService();
  final _discover = DiscoverService();
  final _photos = ShelfPhotoStore();

  static Future<Size> _encodedSize(ui.ImmutableBuffer buffer) async {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  // ML Kit reads the photo upright, so its boxes fit the upright full-size
  // photo. The file itself may be stored sideways (EXIF rotation), so its
  // size is turned to match the shrunk JPEG, which is already upright.
  // Only reads the image headers, not the pixels.
  static Future<({Size full, Size saved})> _sizes(
    String photoPath,
    Uint8List jpeg,
  ) async {
    final full = await _encodedSize(
      await ui.ImmutableBuffer.fromFilePath(photoPath),
    );
    final saved = await _encodedSize(
      await ui.ImmutableBuffer.fromUint8List(jpeg),
    );
    final sideways = (full.width > full.height) != (saved.width > saved.height);
    return (full: sideways ? full.flipped : full, saved: saved);
  }

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
  // When books are found, the shelf photo is kept with an outline for each
  // book; [photo] is null when none were found or saving it failed, which
  // never fails the scan.
  Future<({List<DiscoveredBookModel> books, ShelfPhotoModel? photo})> discover(
    String photoPath,
    Size previewSize,
  ) async {
    final ocr = await _ocr(photoPath, previewSize);

    final (:books, :image) = await _discover.discoverBooks(
      photoPath,
      ocr.blocks,
      previewSize.height.round(),
      previewSize.width.round(),
    );
    if (books.isEmpty) return (books: books, photo: null);

    try {
      final (:full, :saved) = await _sizes(photoPath, image);
      final photo = await _photos.save(
        image,
        width: saved.width.round(),
        height: saved.height.round(),
        bookIds: [for (final b in books) b.id],
        outlines: SpineOutliner.outline(ocr.blocks, books, full),
      );
      debugPrint(
        '[Discover] Outlined ${photo.outlines.length} of ${books.length} books',
      );
      return (books: books, photo: photo);
    } catch (e) {
      debugPrint('Saving shelf photo failed: $e');
      return (books: books, photo: null);
    }
  }

  Future<void> close() => _recognizer.close();
}
