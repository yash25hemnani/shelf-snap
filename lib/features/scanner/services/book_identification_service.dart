import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/core/models/book_model.dart';
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
  // legible, small enough to keep the upload a few hundred KB.
  static const int _maxImageEdge = 1600;
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
      '[Identify] POST $uri (image ${imageBytes.length ~/ 1024} KB)',
    );

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

      if (response.statusCode != 200) {
        debugPrint('[Identify] Failed ${response.statusCode}: ${response.body}');
        return [];
      }
      debugPrint('[Identify] OK ${response.statusCode}');

      final decoded = jsonDecode(response.body);
      final List<dynamic> booksJson =
          (decoded is Map && decoded['books'] is List)
          ? decoded['books'] as List<dynamic>
          : [];

      return booksJson
          .whereType<Map>()
          .where((b) => (b['title'] ?? '').toString().isNotEmpty)
          .map(
            (b) => ScoredBookResult(
              book: BookModel(
                title: b['title'].toString(),
                author: b['author'] as String?,
                isbn: b['isbn'] as String?,
                coverUrl: b['coverUrl'] as String?,
                // A scan result, not yet saved to a library — addedAt gets
                // a real value if/when the user actually adds it to one.
                addedAt: DateTime.now(),
              ),
              score: (b['score'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[Identify] Request failed: $e');
      return [];
    }
  }
}
