import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/search/models/search_query.dart';
import 'package:shelf_snap/features/search/models/search_results.dart';
import 'package:shelf_snap/features/search/services/book_search_service.dart';

final bookSearchServiceProvider = Provider((ref) => BookSearchService());

// Results for one submitted search; the screen passes in the query and
// calls loadMore() as the list nears its end
final searchResultsProvider = AsyncNotifierProvider.autoDispose
    .family<SearchResultsNotifier, SearchResults, SearchQuery>(
      SearchResultsNotifier.new,
    );

class SearchResultsNotifier
    extends AutoDisposeFamilyAsyncNotifier<SearchResults, SearchQuery> {
  // The backend merges genres per page, so a book can come back on a later
  // page too; skip ones already shown
  List<BookModel> _merge(List<BookModel> old, List<BookModel> next) {
    final seen = {for (final book in old) book.workId ?? book.title};
    return [
      ...old,
      ...next.where((book) => seen.add(book.workId ?? book.title)),
    ];
  }

  // An empty page also ends it, since the multi-genre total over-counts
  bool _hasMore(List<BookModel> pageBooks, int page, int total) =>
      pageBooks.isNotEmpty && page * BookSearchService.pageSize < total;

  @override
  Future<SearchResults> build(SearchQuery arg) async {
    if (arg.isEmpty) return const SearchResults();
    final result = await ref.read(bookSearchServiceProvider).searchBooks(arg);
    return SearchResults(
      books: result.books,
      page: 1,
      hasMore: _hasMore(result.books, 1, result.total),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    // The guard stops a fast scroll from loading the same page twice
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    final next = current.page + 1;
    try {
      final result = await ref
          .read(bookSearchServiceProvider)
          .searchBooks(arg, page: next);
      state = AsyncData(
        current.copyWith(
          books: _merge(current.books, result.books),
          page: next,
          hasMore: _hasMore(result.books, next, result.total),
          loadingMore: false,
        ),
      );
    } catch (e) {
      debugPrint('Load more failed: $e');
      // Keep what's shown; scrolling again retries the same page
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}
