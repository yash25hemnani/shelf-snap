import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/dialogs/save_to_library_dialog.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';
import 'package:shelf_snap/features/library/widgets/book_card.dart';
import 'package:shelf_snap/features/search/providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = ''; // What was last submitted and not every key stroke

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addBook(BookModel book) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => SaveToLibraryDialog(books: [book]),
    );

    if (saved != true || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added "${book.title}"')));
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text("Search")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsGeometry.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Title, author or ISBN',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (text) => setState(() {
                _query = text;
              }),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (books) {
                if (_query.length < 2) {
                  return const Center(child: Text('Search for a book to add'));
                }

                if (books.isEmpty) {
                  return const Center(child: Text('No books found'));
                }

                return GridView.builder(
                  padding: const EdgeInsetsGeometry.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
              error: (err, stack) => Center(child: Text('Error: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
