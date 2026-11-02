import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';
import 'package:shelf_snap/features/library/sheets/save_to_library_sheet.dart';
import 'package:shelf_snap/features/library/widgets/book_card.dart';
import 'package:shelf_snap/features/scanner/screens/scanner_screen.dart';
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
                  return _EmptySearch(
                    onScan: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ScannerScreen(),
                        fullscreenDialog: true,
                      ),
                    ),
                  );
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
              error: (err, stack) => Center(child: Text('$err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

// Before the first search: what to type, and the barcode scanner as the
// quicker way when the book is in hand
class _EmptySearch extends StatelessWidget {
  final VoidCallback onScan;

  const _EmptySearch({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Find a book to add',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Type a title, an author or the ISBN from the back cover',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan a barcode instead'),
            ),
          ],
        ),
      ),
    );
  }
}
