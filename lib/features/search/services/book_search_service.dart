import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:http/http.dart' as http;

class BookSearchService {
  Future<List<BookModel>> searchBooks(String query) =>
      _getBooks('/search-books', {'q': query});

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

    if (response.statusCode != 200) {
      throw Exception('Search failed (${response.statusCode})');
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
