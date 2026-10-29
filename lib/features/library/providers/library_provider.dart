import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/library/repositories/library_repository.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

final libraryRepositoryProvider = Provider((ref) => LibraryRepository());

// Library picked most recently in a save sheet; resets when the user changes
final lastLibraryIdProvider = StateProvider<String?>((ref) {
  ref.watch(currentUidProvider);
  return null;
});

// Books loaded per page in the library detail grid
const booksPageSize = 30;

// How many books the detail grid has asked for so far
final booksLimitProvider = StateProvider.autoDispose.family<int, String>(
  (ref, libraryId) => booksPageSize,
);

// All libraries for a user
final userLibrariesProvider = StreamProvider.family<List<LibraryModel>, String>(
  (ref, userId) =>
      ref.watch(libraryRepositoryProvider).watchUserLibraries(userId),
);

// Newest books in a library, up to the current limit
final libraryBooksProvider = StreamProvider.autoDispose
    .family<List<BookModel>, String>((ref, libraryId) {
      final limit = ref.watch(booksLimitProvider(libraryId));

      return ref
          .watch(libraryRepositoryProvider)
          .watchBooks(libraryId, limit: limit);
    });

final libraryProvider = StreamProvider.autoDispose
    .family<LibraryModel?, String>(
      (ref, libraryId) =>
          ref.watch(libraryRepositoryProvider).watchLibrary(libraryId),
    );

// Member profiles of a library, owner first, then by name
final libraryMembersProvider = StreamProvider.autoDispose
    .family<List<UserModel>, String>((ref, libraryId) {
      final library = ref.watch(libraryProvider(libraryId)).valueOrNull;
      if (library == null) return const Stream.empty();

      return ref
          .watch(userRepositoryProvider)
          .watchUsers(library.members)
          .map(
            (users) => [...users]
              ..sort((a, b) {
                if (a.uid == library.ownerId) return -1;
                if (b.uid == library.ownerId) return 1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              }),
          );
    });

// Text typed in a library's search box
final bookSearchQueryProvider = StateProvider.autoDispose
    .family<String, String>((ref, libraryId) => '');

// Books matching every word of the search; empty when the box is empty
final libraryBookSearchProvider = StreamProvider.autoDispose
    .family<List<BookModel>, String>((ref, libraryId) {
      final words = BookModel.sanitizeWords(
        ref.watch(bookSearchQueryProvider(libraryId)),
      );
      if (words.isEmpty) return Stream.value(const []);

      words.sort((a, b) => b.length.compareTo(a.length));

      return ref
          .watch(libraryRepositoryProvider)
          .searchBooks(libraryId, words.first)
          .map(
            (books) => books.where((book) {
              final tokens = book.searchTokens.toSet();
              return words.every(tokens.contains);
            }).toList(),
          );
    });
