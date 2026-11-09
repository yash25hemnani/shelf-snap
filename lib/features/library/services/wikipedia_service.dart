import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/features/library/models/wiki_book.dart';

// Looks a book up on Wikipedia through the API, which picks the page whose
// infobox author matches
class WikipediaService {
  // The backend may try a guess request and a search, each up to 8s
  static const _timeout = Duration(seconds: 20);

  // The book's Wikipedia page, or null when none matches the author
  Future<WikiBook?> findBook(String title, String author) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final idToken = await user.getIdToken();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/wikipedia-book',
    ).replace(queryParameters: {'title': title, 'author': author});

    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $idToken'})
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Wikipedia lookup failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final book = decoded is Map ? decoded['book'] : null;
    return book is Map<String, dynamic> ? WikiBook.fromApi(book) : null;
  }
}
