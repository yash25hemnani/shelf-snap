import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/search/models/search_query.dart';
import 'package:shelf_snap/features/search/services/book_search_service.dart';

final bookSearchServiceProvider = Provider((ref) => BookSearchService());

// Results for one submitted search; the screen passes in the query
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<BookModel>, SearchQuery>((ref, query) {
      if (query.isEmpty) return [];
      return ref.watch(bookSearchServiceProvider).searchBooks(query);
    });
