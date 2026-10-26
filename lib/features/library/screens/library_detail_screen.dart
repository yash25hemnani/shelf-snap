import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/sheets/invite_sheet.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';
import 'package:shelf_snap/features/library/widgets/book_card.dart';

class LibraryDetailScreen extends ConsumerWidget {
  final LibraryModel library;

  const LibraryDetailScreen({super.key, required this.library});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider(library.id!));
    final isOwner = library.ownerId == AuthService().currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(library.name),
        actions: [
          // Only the owner can invite people
          if (isOwner)
            IconButton(
              tooltip: 'Invite',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => InviteSheet.show(context, library),
            ),
        ],
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const Center(
              child: Text('No Books Yet. Scan a Shelf or Add Manually!'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisExtent: 210,
              crossAxisSpacing: 12,
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
                    builder: (_) => BookDetailScreen(book: book),
                  ),
                ),
              );
            },
          );
        },
        error: (err, stack) {
          return Center(child: Text('Error: $err'));
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
