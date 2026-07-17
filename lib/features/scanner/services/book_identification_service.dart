import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/features/scanner/models/identified_book_model.dart';

/// Sends on-device OCR output to a self-hosted Node.js API (Gemini-backed),
/// which groups fragmented/garbled text blocks into individual books and
/// infers likely real titles/authors using world knowledge.
class BookIdentificationService {
  static const String _baseUrl = 'https://shelf-snap-gemini-wrapper-sand.vercel.app';

  /// Groups [blocks] of raw OCR text into distinct books and resolves
  /// likely real titles/authors for each. [imageWidth]/[imageHeight] give
  /// the API the image's coordinate space so it can reason about block
  /// positions. Returns an empty list on any failure — callers don't need
  /// to special-case errors, just treat "no books" the same way.
  Future<List<IdentifiedBook>> identifyBooks(
    List<TextBlock> blocks,
    int imageWidth,
    int imageHeight,
  ) async {
    if (blocks.isEmpty) {
      return [];
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }
    final idToken = await user.getIdToken();

    final payload = {
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

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/identify-books'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> booksJson =
          (decoded is Map && decoded['books'] is List)
          ? decoded['books'] as List<dynamic>
          : [];

      return booksJson
          .whereType<Map>()
          .map(
            (b) => IdentifiedBook(
              title: (b['title'] ?? '').toString(),
              author: (b['author'] ?? '').toString(),
            ),
          )
          .where((b) => b.title.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }
}
