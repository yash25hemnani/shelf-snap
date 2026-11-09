import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';

// Sends a shelf photo to the API's /discover route. Same request as
// /identify-books, but each book comes back with 0–2 genres.
// Unlike BookIdentificationService it throws on failure, so Discover mode
// can tell "no books found" apart from "the request failed".
class DiscoverService {
  final _baseUrl = ApiConfig.baseUrl;

  // Same sizes as BookIdentificationService, to keep Groq image tokens low
  static const int _maxImageEdge = 1200;
  static const int _jpegQuality = 80;

  // Vision model + Google Books lookups can take a while on a full shelf
  static const Duration _timeout = Duration(seconds: 60);

  // Books on the shelf in [imagePath]. Books with no title or author are
  // dropped, since they can't be saved. [blocks] are OCR hints, in the
  // [imageWidth] x [imageHeight] coordinate space.
  Future<List<DiscoveredBookModel>> discoverBooks(
    String imagePath,
    List<TextBlock> blocks,
    int imageWidth,
    int imageHeight,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Sign in to use Discover');
    final idToken = await user.getIdToken();

    // Also applies EXIF rotation so the model sees the photo upright
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
      debugPrint('[Discover] Image compression failed: $e');
      throw Exception('Could not read the photo');
    }
    if (imageBytes == null) throw Exception('Could not read the photo');

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

    final uri = Uri.parse('$_baseUrl/discover');
    final watch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint(
        '[Discover] Request failed after ${watch.elapsedMilliseconds} ms: $e',
      );
      throw Exception('Could not reach the server. Check your connection.');
    }

    if (response.statusCode != 200) {
      debugPrint('[Discover] Failed ${response.statusCode}: ${response.body}');
      // 503 = both vision models are busy or out of quota
      throw Exception(
        response.statusCode == 503
            ? 'Discover is busy right now. Try again in a minute.'
            : 'Could not read the shelf. Try another photo.',
      );
    }

    final decoded = jsonDecode(response.body);
    final booksJson = (decoded is Map && decoded['books'] is List)
        ? decoded['books'] as List
        : const [];

    final books = [
      for (final json in booksJson.whereType<Map<String, dynamic>>())
        ?DiscoveredBookModel.fromApi(json),
    ];

    debugPrint(
      '[Discover] OK in ${watch.elapsedMilliseconds} ms, ${books.length} books',
    );
    for (final b in books) {
      debugPrint('[Discover]   $b');
    }
    return books;
  }
}
