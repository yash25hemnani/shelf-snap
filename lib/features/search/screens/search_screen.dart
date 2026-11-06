import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/models/genre.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';
import 'package:shelf_snap/features/library/sheets/save_to_library_sheet.dart';
import 'package:shelf_snap/features/library/widgets/book_card.dart';
import 'package:shelf_snap/features/search/models/search_query.dart';
import 'package:shelf_snap/features/search/providers/search_provider.dart';
import 'package:shelf_snap/features/search/sheets/search_filter_sheet.dart';
import 'package:shelf_snap/features/search/widgets/genre_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  // What was last submitted and not every key stroke
  SearchQuery _query = const SearchQuery();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Picking a field or genre searches right away with the typed text
  void _update(SearchQuery query) {
    setState(() {
      _query = query.copyWith(text: _controller.text);
    });
  }

  void _toggleGenre(Genre genre, bool selected) {
    final genres = {..._query.genres};
    selected ? genres.add(genre) : genres.remove(genre);
    _update(_query.copyWith(genres: genres));
  }

  void _toggleField() {
    _update(
      _query.copyWith(
        field: _query.field == SearchField.title
            ? SearchField.author
            : SearchField.title,
      ),
    );
  }

  // Back to the genre shelf, keeping the Title/Author choice
  void _clear() {
    _controller.clear();
    setState(() => _query = SearchQuery(field: _query.field));
  }

  Future<void> _openFilters() async {
    final genres = await SearchFilterSheet.show(
      context,
      genres: _query.genres,
    );
    if (genres != null && mounted) {
      _update(_query.copyWith(genres: genres));
    }
  }

  // The sheet shows its own message, including "already in this library".
  // True once the book is saved.
  Future<bool> _addBook(BookModel book) async {
    final saved = await SaveToLibrarySheet.show(context, book: book);
    return saved == true;
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleTextStyle: Theme.of(context).textTheme.headlineMedium,
        title: const Text("Search"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _query.field == SearchField.title
                    ? 'Title or ISBN'
                    : 'Author',
                prefixIcon: const Icon(Icons.search),
                // Flips which field the typed text searches
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    onPressed: _toggleField,
                    child: Text(
                      _query.field == SearchField.title ? 'Title' : 'Author',
                    ),
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _update(_query),
            ),
          ),
          if (!_query.isEmpty)
            _FilterRow(
              genres: _query.genres,
              onFilters: _openFilters,
              onRemove: (genre) => _toggleGenre(genre, false),
              onClear: _clear,
            ),
          Expanded(
            child: _query.isEmpty
                ? _GenreShelf(
                    onGenre: (genre) => _update(_query.copyWith(genres: {genre})),
                  )
                : resultsAsync.when(
                    data: (books) {
                      if (books.isEmpty) {
                        return const Center(child: Text('No books found'));
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 130,
                              mainAxisExtent: 210,
                              crossAxisSpacing: 13,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return BookCard(
                            book: book,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookDetailScreen(
                                  book: book,
                                  onAdd: () => _addBook(book),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    error: (err, stack) => Center(child: Text('$err')),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
          ),
        ],
      ),
    );
  }
}

// Shown once a search runs: the filter sheet button, the picked genres
// (each removable) and a way back to the genre shelf
class _FilterRow extends StatelessWidget {
  final Set<Genre> genres;
  final VoidCallback onFilters;
  final ValueChanged<Genre> onRemove;
  final VoidCallback onClear;

  const _FilterRow({
    required this.genres,
    required this.onFilters,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Center(
            child: OutlinedButton.icon(
              onPressed: onFilters,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                genres.isEmpty ? 'Filters' : 'Filters · ${genres.length}',
              ),
            ),
          ),
          for (final genre in genres)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: InputChip(
                  label: Text(genre.label),
                  onDeleted: () => onRemove(genre),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Center(
              child: TextButton(
                onPressed: onClear,
                child: const Text('Clear'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Before the first search: all genres as a two-column shelf, 12 rows of 2
class _GenreShelf extends StatelessWidget {
  final ValueChanged<Genre> onGenre;

  const _GenreShelf({required this.onGenre});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Text(
          'Browse by genre',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 64,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: Genre.values.length,
          itemBuilder: (context, index) {
            final genre = Genre.values[index];
            return GenreTile(genre: genre, onTap: () => onGenre(genre));
          },
        ),
      ],
    );
  }
}
