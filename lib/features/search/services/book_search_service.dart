import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/search/models/search_query.dart';
import 'package:http/http.dart' as http;

// A search failure with a message that's safe to show on screen
class SearchException implements Exception {
  final String message;
  const SearchException(this.message);

  @override
  String toString() => message;
}

class BookSearchService {
  // The normalized ISBN if [text] is an ISBN-10 or ISBN-13 (hyphens and
  // spaces allowed), otherwise null
  String? _parseIsbn(String text) {
    final isbn = text.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
    return RegExp(r'^(\d{9}[\dX]|\d{13})$').hasMatch(isbn) ? isbn : null;
  }

  /// Open Library search by title or author and up to 3 genres. A typed
  /// ISBN goes to the exact lookup instead.
  Future<List<BookModel>> searchBooks(SearchQuery query) async {
    final isbn = _parseIsbn(query.trimmedText);
    if (isbn != null && query.genres.isEmpty) {
      final book = await lookupIsbn(isbn);
      return book == null ? [] : [book];
    }

    return _getBooks('/search-books', {
      if (query.hasText) query.field.name: query.trimmedText,
      if (query.genres.isNotEmpty)
        'genre': query.genres.map((genre) => genre.subject).join(','),
      'limit': '20',
    });
  }

  /// Exact ISBN lookup (Open Library on the backend). Null if not found.
  Future<BookModel?> lookupIsbn(String isbn) async {
    final books = await _getBooks('/isbn-search', {'isbn': isbn});
    return books.isEmpty ? null : books.first;
  }

  Future<List<BookModel>> _getBooks(
    String path,
    Map<String, String> params,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: params);

    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $idToken'})
        .timeout(const Duration(seconds: 15));

    // 503 means Open Library is rate limiting the backend for a moment
    if (response.statusCode == 503) {
      throw const SearchException('Search is busy, try again shortly');
    }
    if (response.statusCode != 200) {
      throw SearchException('Search failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> booksJson = (decoded is Map && decoded['books'] is List)
        ? decoded['books'] as List<dynamic>
        : [];

    return booksJson
        .whereType<Map<String, dynamic>>()
        .map(BookModel.fromApi)
        .toList();
  }
}
