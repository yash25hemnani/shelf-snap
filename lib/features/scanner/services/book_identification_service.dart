import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';

/// Sends the shelf photo plus on-device OCR output to a self-hosted Node.js
/// API. The API reads the spines with a vision model (using the OCR blocks
/// as hints), looks each book up on Google Books, and returns only strong
/// matches with their details and scores.
class BookIdentificationService {
  // Set API_BASE_URL in .env, or pass
  //   flutter run --dart-define=API_BASE_URL=https://shelf-snap-wrapper.vercel.app
  // Defaults to the local server (reached via `adb reverse tcp:3000 tcp:3000`).
  final _baseUrl = ApiConfig.baseUrl;

  // Long edge of the uploaded image. Large enough for spine text to stay
  // legible, small enough to keep Groq's image tokens (8,000 per minute
  // on the current plan) low.
  static const int _maxImageEdge = 1200;
  static const int _jpegQuality = 80;

  /// Identifies the books in the photo at [imagePath]. [blocks] are raw OCR
  /// text blocks sent as hints, and [imageWidth]/[imageHeight] give the API
  /// their coordinate space. Returns an empty list on any failure — callers
  /// don't need to special-case errors, just treat "no books" the same way.
  Future<List<ScoredBookResult>> identifyBooks(
    String imagePath,
    List<TextBlock> blocks,
    int imageWidth,
    int imageHeight,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[Identify] No signed-in user, skipping request');
      return [];
    }
    final idToken = await user.getIdToken();

    // Downscale + re-encode; also applies EXIF rotation so the model sees
    // the photo upright.
    final compressWatch = Stopwatch()..start();
    final Uint8List? imageBytes;
    try {
      imageBytes = await FlutterImageCompress.compressWithFile(
        imagePath,
        minWidth: _maxImageEdge,
        minHeight: _maxImageEdge,
        quality: _jpegQuality,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      debugPrint('[Identify] Image compression failed: $e');
      return [];
    }
    if (imageBytes == null) {
      debugPrint('[Identify] Image compression failed, skipping request');
      return [];
    }
    debugPrint(
      '[Identify] Compressed to ${imageBytes.length ~/ 1024} KB'
      ' in ${compressWatch.elapsedMilliseconds} ms',
    );

    final payload = {
      'image': base64Encode(imageBytes),
      'imageMimeType': 'image/jpeg',
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'blocks': blocks
          .map(
            (b) => {
              'text': b.text,
              'left': b.boundingBox.left.round(),
              'top': b.boundingBox.top.round(),
              'right': b.boundingBox.right.round(),
              'bottom': b.boundingBox.bottom.round(),
            },
          )
          .toList(),
    };

    final uri = Uri.parse('$_baseUrl/identify-books');
    debugPrint(
      '[Identify] POST $uri (${blocks.length} OCR blocks, '
      '${imageWidth}x$imageHeight)',
    );

    final requestWatch = Stopwatch()..start();
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      final elapsed = requestWatch.elapsedMilliseconds;
      if (response.statusCode != 200) {
        debugPrint(
          '[Identify] Failed ${response.statusCode} after $elapsed ms: '
          '${response.body}',
        );
        return [];
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> booksJson =
          (decoded is Map && decoded['books'] is List)
          ? decoded['books'] as List<dynamic>
          : [];

      final results = booksJson
          .whereType<Map<String, dynamic>>()
          .map(
            (b) => ScoredBookResult(
              book: BookModel.fromApi(b),
              score: (b['score'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();

      debugPrint(
        '[Identify] OK in $elapsed ms, ${results.length} books matched',
      );
      for (final r in results) {
        debugPrint(
          '[Identify]   ${r.score.toStringAsFixed(2)}  "${r.book.title}"'
          ' by ${r.book.authorLine ?? '?'} (isbn ${r.book.isbn ?? '-'})',
        );
      }
      return results;
    } catch (e) {
      debugPrint(
        '[Identify] Request failed after '
        '${requestWatch.elapsedMilliseconds} ms: $e',
      );
      return [];
    }
  }
}
