import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/wiki_book.dart';
import 'package:shelf_snap/features/library/services/wikipedia_service.dart';

final wikipediaServiceProvider = Provider((ref) => WikipediaService());

// A book's Wikipedia page by title and first author; null when none matches.
// Kept for the session once found, so reopening a book doesn't fetch again.
// No Firestore involved, so it costs no reads.
final wikiBookProvider = FutureProvider.autoDispose
    .family<WikiBook?, ({String title, String author})>((ref, key) async {
      final book = await ref
          .watch(wikipediaServiceProvider)
          .findBook(key.title, key.author);
      ref.keepAlive();
      return book;
    });
