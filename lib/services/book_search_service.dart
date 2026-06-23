import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/book_result.dart';

/// Searches Google Books for metadata (title, author, ISBN, cover) matching
/// OCR'd spine text.
///
/// Since OCR text is often imperfect (typos, garbled trailing words), this
/// service uses a "retry ladder": if the full query returns no results, it
/// progressively drops trailing words and retries, since the most reliable
/// part of a spine's text is usually the first few words of the title.
class BookSearchService {
  static String get _apiKey => dotenv.env['GOOGLE_BOOKS_API_KEY'] ?? '';

  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  /// Searches for a book matching [ocrText], trying progressively shorter
  /// queries (dropping trailing words) until results are found or all
  /// variants are exhausted.
  ///
  /// Returns an empty list if no variant returns results.
  Future<List<BookResult>> search(String ocrText) async {
    final cleanedText = _cleanOcrText(ocrText);
    // Split into words, removing empty strings (e.g. from double spaces).
    final words = cleanedText
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();

    if (words.isEmpty) return [];

    // Try the full query first, then progressively shorter prefixes.
    // e.g. for ["THE", "ELEPHANT", "VANTaSHES"]:
    //   1. "THE ELEPHANT VANTSHES"
    //   2. "THE ELEPHANT"
    //   3. "THE"
    for (int len = words.length; len >= 1; len--) {
      final query = words.sublist(0, len).join(' ');
      final results = await _querySingle(query);

      if (results.isNotEmpty) {
        return results;
      }
    }

    // Every variant returned zero results.
    return [];
  }

  /// Performs a single Google Books API query and parses the response.
  Future<List<BookResult>> _querySingle(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = Uri.parse('$_baseUrl?q=$encodedQuery&key=$_apiKey');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Google Books API error: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final items = data['items'] as List<dynamic>?;

    if (items == null) return [];

    return items.map((item) => _parseItem(item)).toList();
  }

  /// Converts a single Google Books API "item" into a [BookResult].
  BookResult _parseItem(Map<String, dynamic> item) {
    final volumeInfo = item['volumeInfo'] as Map<String, dynamic>? ?? {};

    final title = volumeInfo['title'] as String? ?? 'Unknown Title';

    final authorsList = volumeInfo['authors'] as List<dynamic>?;
    final author = authorsList?.join(', ');

    String? isbn;
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
    if (identifiers != null) {
      for (final id in identifiers) {
        if (id['type'] == 'ISBN_13') {
          isbn = id['identifier'] as String?;
          break;
        }
      }
      if (isbn == null) {
        for (final id in identifiers) {
          if (id['type'] == 'ISBN_10') {
            isbn = id['identifier'] as String?;
            break;
          }
        }
      }
    }

    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    final coverUrl = imageLinks?['thumbnail'] as String?;

    // Parse categories — Google Books returns a List<String> or null.
    final rawCategories = volumeInfo['categories'] as List<dynamic>?;
    final genres = rawCategories?.map((c) => c.toString()).toList() ?? [];

    return BookResult(
      title: title,
      author: author,
      isbn: isbn,
      coverUrl: coverUrl,
      genres: genres,
    );
  }
}

final _knownPublishers = [
  'ROUTLEDGE', 'ROUTLEDCA', 'PENGUIN', 'VIKING', 'HARPER', 'COLLINS',
  'OXFORD', 'CAMBRIDGE', 'SPRINGER', 'WILEY', 'NORTON', 'RANDOM HOUSE',
  'MACMILLAN', 'BLOOMSBURY', 'PICADOR', 'VINTAGE', 'ANCHOR', 'KNOPF',
  'SIMON SCHUSTER', 'HACHETTE', 'SCHOLASTIC', 'PEARSON',
];

String _cleanOcrText(String text) {
  String cleaned = text.toUpperCase();

  // Strip known publisher names
  for (final publisher in _knownPublishers) {
    cleaned = cleaned.replaceAll(publisher, '');
  }

  // Replace digits embedded in words
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'(?<=[a-zA-Z])\d|\d(?=[a-zA-Z])'),
        (match) => switch (match.group(0)) {
      '0' => 'O',
      '1' => 'I',
      '5' => 'S',
      '8' => 'B',
      _ => match.group(0)!,
    },
  );

  // Collapse multiple spaces left by removals
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}