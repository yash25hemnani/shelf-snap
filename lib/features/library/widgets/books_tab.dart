import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';
import 'package:shelf_snap/features/library/widgets/book_card.dart';

// Search box over a library's books, then either the search results or
// the newest books with paging
class BooksTab extends ConsumerStatefulWidget {
  final String libraryId;

  const BooksTab({super.key, required this.libraryId});

  @override
  ConsumerState<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends ConsumerState<BooksTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Waits for a pause in typing before searching
  void _onChanged(String text) {
    setState(() {}); // shows or hides the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(bookSearchQueryProvider(widget.libraryId).notifier).state = text;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(bookSearchQueryProvider(widget.libraryId).notifier).state = '';
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(bookSearchQueryProvider(widget.libraryId));
    // A single letter isn't searchable, so the full list stays
    final searching = BookModel.sanitizeWords(query).isNotEmpty;

    return Column(
      children: [
        // White band under the field, so books scroll out of sight below it
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: _onChanged,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by title or author',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        Expanded(child: searching ? _buildResults() : _buildAllBooks()),
      ],
    );
  }

  Widget _buildResults() {
    final resultsAsync = ref.watch(libraryBookSearchProvider(widget.libraryId));

    return resultsAsync.when(
      // Keeps the old results on screen while the next search runs
      skipLoadingOnReload: true,
      data: (books) {
        if (books.isEmpty) {
          return const Center(child: Text('No books match your search'));
        }
        return _BookGrid(books: books);
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildAllBooks() {
    final booksAsync = ref.watch(libraryBooksProvider(widget.libraryId));

    return booksAsync.when(
      // Keeps the grid and its scroll position while the next page loads
      skipLoadingOnReload: true,
      data: (books) {
        if (books.isEmpty) {
          return const Center(
            child: Text('No Books Yet. Scan a Shelf or Add Manually!'),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            final limit = ref.read(booksLimitProvider(widget.libraryId));
            // A full page means there may be more books after it
            final hasMore = books.length >= limit;
            if (n.metrics.extentAfter < 400 &&
                hasMore &&
                !booksAsync.isLoading) {
              ref.read(booksLimitProvider(widget.libraryId).notifier).state +=
                  booksPageSize;
            }
            return false;
          },
          child: _BookGrid(books: books, loadingMore: booksAsync.isLoading),
        );
      },
      error: (err, stack) => Center(child: Text('Error: $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

// Grid of book covers that open the book page
class _BookGrid extends StatelessWidget {
  final List<BookModel> books;
  // Adds a spinner cell at the end while the next page loads
  final bool loadingMore;

  const _BookGrid({required this.books, this.loadingMore = false});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Top is small since the search band already leaves a gap
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 210,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == books.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final book = books[index];
        return BookCard(
          book: book,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
          ),
        );
      },
    );
  }
}
