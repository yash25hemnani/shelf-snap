import 'package:flutter/foundation.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

// Every page loaded so far for one search, and whether more can load
@immutable
class SearchResults {
  final List<BookModel> books;
  final int page;
  final bool hasMore;
  final bool loadingMore;

  const SearchResults({
    this.books = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
  });

  SearchResults copyWith({
    List<BookModel>? books,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return SearchResults(
      books: books ?? this.books,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}
