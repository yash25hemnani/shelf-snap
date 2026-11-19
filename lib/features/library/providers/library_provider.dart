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

// Public libraries anyone can find, newest activity first, up to 20
final publicLibrariesProvider = StreamProvider.autoDispose<List<LibraryModel>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchPublicLibraries(),
);

// Libraries the user can add books to: ones they own or edit.
// Viewers can't save books there, so pickers don't list them.
final editableLibrariesProvider =
    Provider.family<AsyncValue<List<LibraryModel>>, String>((ref, userId) {
      return ref
          .watch(userLibrariesProvider(userId))
          .whenData(
            (libraries) => libraries
                .where((l) => l.id != null && l.canEdit(userId))
                .toList(),
          );
    });

// True when the signed-in user edits this library; null while it loads.
// select() so a count change on the library doesn't restart book queries.
final canEditLibraryProvider = Provider.autoDispose.family<bool?, String>((
  ref,
  libraryId,
) {
  final uid = ref.watch(currentUidProvider).valueOrNull;
  return ref.watch(
    libraryProvider(libraryId).select((a) => a.valueOrNull?.canEdit(uid)),
  );
});

// Newest books in a library, up to the current limit. Viewers only get
// public books, so this waits until it knows who is looking.
final libraryBooksProvider = StreamProvider.autoDispose
    .family<List<BookModel>, String>((ref, libraryId) {
      final limit = ref.watch(booksLimitProvider(libraryId));
      final canEdit = ref.watch(canEditLibraryProvider(libraryId));
      if (canEdit == null) return const Stream.empty();

      return ref
          .watch(libraryRepositoryProvider)
          .watchBooks(libraryId, limit: limit, publicOnly: !canEdit);
    });

final libraryProvider = StreamProvider.autoDispose
    .family<LibraryModel?, String>(
      (ref, libraryId) =>
          ref.watch(libraryRepositoryProvider).watchLibrary(libraryId),
    );

// One saved book, live, so edits show on the book page
final libraryBookProvider = StreamProvider.autoDispose
    .family<BookModel?, ({String libraryId, String bookId})>(
      (ref, ids) => ref
          .watch(libraryRepositoryProvider)
          .watchBook(ids.libraryId, ids.bookId),
    );

// Every edition of one book in a library the user owns. Owners see
// private books too, so there's no visibility filter.
final ownedEditionsProvider = StreamProvider.autoDispose
    .family<List<BookModel>, ({String libraryId, String readingKey})>(
      (ref, args) => ref
          .watch(libraryRepositoryProvider)
          .watchEditions(args.libraryId, args.readingKey, publicOnly: false),
    );

// Keys from one chunk of search results that the user's own libraries
// hold. Keyed by the joined keys, since lists don't compare by value.
final ownedReadingKeysProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, joinedKeys) async {
      final uid = ref.watch(currentUidProvider).valueOrNull;
      if (uid == null || joinedKeys.isEmpty) return {};

      // select() so a bookCount change doesn't run the queries again
      final ownedIds = ref.watch(
        userLibrariesProvider(uid).select(
          (a) => (a.valueOrNull ?? const <LibraryModel>[])
              .where((l) => l.ownerId == uid && l.id != null)
              .map((l) => l.id!)
              .join('|'),
        ),
      );
      if (ownedIds.isEmpty) return {};

      final repo = ref.watch(libraryRepositoryProvider);
      final keys = joinedKeys.split('|');
      final sets = await Future.wait([
        for (final id in ownedIds.split('|')) repo.ownedKeys(id, keys),
      ]);
      return {for (final s in sets) ...s};
    });

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

// Books in one library matching every word of [query]; for search boxes
// that keep their own text, like the lend sheet
final bookQuerySearchProvider = StreamProvider.autoDispose
    .family<List<BookModel>, ({String libraryId, String query})>((ref, args) {
      final words = BookModel.sanitizeWords(args.query);
      if (words.isEmpty) return Stream.value(const []);

      // The longest word narrows the query the most
      words.sort((a, b) => b.length.compareTo(a.length));

      final canEdit = ref.watch(canEditLibraryProvider(args.libraryId));
      if (canEdit == null) return const Stream.empty();

      return ref
          .watch(libraryRepositoryProvider)
          .searchBooks(
            args.libraryId,
            words.first,
            publicOnly: !canEdit,
            limit: 20,
          )
          .map(
            (books) => books.where((book) {
              final tokens = book.searchTokens.toSet();
              return words.every(tokens.contains);
            }).toList(),
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

      final canEdit = ref.watch(canEditLibraryProvider(libraryId));
      if (canEdit == null) return const Stream.empty();

      return ref
          .watch(libraryRepositoryProvider)
          .searchBooks(libraryId, words.first, publicOnly: !canEdit)
          .map(
            (books) => books.where((book) {
              final tokens = book.searchTokens.toSet();
              return words.every(tokens.contains);
            }).toList(),
          );
    });
