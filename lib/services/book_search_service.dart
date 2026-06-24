import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/book_result.dart';

/// Searches Google Books for metadata (title, author, ISBN, cover) matching
/// a book title/author already resolved by Gemini (see
/// [BookIdentificationService]) — not raw OCR text.
///
/// Gemini's resolved title is usually accurate, but it doesn't always match
/// Google Books' exact listing (subtitles, alternate editions, etc.), so
/// this service uses a "retry ladder": if the full query returns no results,
/// it progressively drops trailing words and retries, since the title at
/// the front of the query is the most reliable part.
class BookSearchService {
  static String get _apiKey => dotenv.env['GOOGLE_BOOKS_API_KEY'] ?? '';

  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';

  /// Searches for a book matching [query] (title, or "title author"),
  /// trying progressively shorter prefixes (dropping trailing words) until
  /// results are found or all variants are exhausted.
  ///
  /// Returns an empty list if no variant returns results.
  Future<List<BookResult>> search(String query) async {
    final words = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return [];

    // Try the full query first, then progressively shorter prefixes.
    // e.g. for ["The", "Elephant", "Vanishes", "Murakami"]:
    //   1. "The Elephant Vanishes Murakami"
    //   2. "The Elephant Vanishes"
    //   3. "The Elephant"
    //   4. "The"
    for (int len = words.length; len >= 1; len--) {
      final candidateQuery = words.sublist(0, len).join(' ');
      final results = await _querySingle(candidateQuery);

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
      // This is a search candidate, not yet saved to a library — addedAt
      // gets a real value if/when the user actually adds it to one.
      addedAt: DateTime.now(),
    );
  }
}