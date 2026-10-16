import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/models/book_model.dart';
import 'package:shelf_snap/features/search/services/book_search_service.dart';

final bookSearchServiceProvider = Provider((ref) => BookSearchService());

// Results for one query; the screen passes in what the user typed
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<BookModel>, String>((ref, query) {
      final trimmed = query.trim();
      if (trimmed.length < 2) return []; // backend rejects < 2 with a 400
      return ref.watch(bookSearchServiceProvider).searchBooks(trimmed);
    });
