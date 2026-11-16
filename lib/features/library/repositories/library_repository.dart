import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

class LibraryRepository {
  final _db = FirebaseFirestore.instance;

  // Create a library, returning its generated id
  Future<String> createLibrary(LibraryModel library) async {
    final data = library.toMap();
    // Ensure owner in members
    data["members"] = {...library.members, library.ownerId}.toList();
    data["editors"] = {library.ownerId}.toList();
    final doc = await _db.collection("libraries").add(data);
    return doc.id;
  }

  // Only the fields the edit form changes, so counts and members are untouched
  Future<void> updateLibrary(LibraryModel library) {
    return _db.collection('libraries').doc(library.id).update({
      'name': library.name,
      'description': library.description,
      'banner': library.banner,
      'updatedAt': Timestamp.now(),
    });
  }

  // Stream and watch all libraries for a user
  Stream<List<LibraryModel>> watchUserLibraries(String userId) {
    return _db
        .collection("libraries")
        .where("members", arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LibraryModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<LibraryModel?> watchLibrary(String libraryId) {
    return _db.collection('libraries').doc(libraryId).snapshots().map((snap) {
      // Null once the library is deleted
      if (!snap.exists) return null;

      return LibraryModel.fromMap(libraryId, snap.data()!);
    });
  }

  // Find the doc for the same edition in a library, or null if there isn't one
  Future<DocumentReference<Map<String, dynamic>>?> findBookInLibrary(
    String libraryId,
    BookModel book,
  ) async {
    if (book.isbn == null) return null;

    final existingBook = await _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
        .where('isbn', isEqualTo: book.isbn)
        .limit(1)
        .get();

    return existingBook.docs.isEmpty ? null : existingBook.docs.first.reference;
  }

  // Adds books to a library. A book already there, or repeated in this list,
  // becomes one more copy. Returns how many were new and how many were copies.
  Future<({int added, int copies})> addBooks(
    String libraryId,
    List<BookModel> books,
  ) async {
    final libraryRef = _db.collection('libraries').doc(libraryId);
    final batch = _db.batch();
    final now = DateTime.now();

    // Books created earlier in this call, by ISBN, since the database
    // doesn't have them yet
    final created = <String, DocumentReference<Map<String, dynamic>>>{};
    var added = 0;
    var copies = 0;

    for (final book in books) {
      final isbn = book.isbn;
      final existingRef =
          (isbn == null ? null : created[isbn]) ??
          await findBookInLibrary(libraryId, book);

      if (existingRef != null) {
        batch.update(existingRef, {'noOfCopies': FieldValue.increment(1)});
        copies++;
        continue;
      }

      final bookRef = libraryRef.collection('books').doc();
      batch.set(bookRef, book.copyWith(addedAt: now).toMap());
      if (isbn != null) created[isbn] = bookRef;
      added++;
    }

    // Every book is one more physical copy; only new docs are new editions
    batch.update(libraryRef, {
      'bookCount': FieldValue.increment(books.length),
      'uniqueCount': FieldValue.increment(added),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();
    return (added: added, copies: copies);
  }

  // One more copy of a book already in the library. Goes by doc id, so it
  // also works for editions without an ISBN.
  Future<void> addCopy(String libraryId, String bookId) {
    final libraryRef = _db.collection('libraries').doc(libraryId);
    final batch = _db.batch()
      ..update(libraryRef.collection('books').doc(bookId), {
        'noOfCopies': FieldValue.increment(1),
      })
      ..update(libraryRef, {
        'bookCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });
    return batch.commit();
  }

  // Which of [keys] this library has, in any edition. At most 30 keys,
  // Firestore's limit for whereIn.
  Future<Set<String>> ownedKeys(String libraryId, List<String> keys) async {
    if (keys.isEmpty) return {};
    final snap = await _books(
      libraryId,
      false,
    ).where('readingKey', whereIn: keys).get();
    return {for (final d in snap.docs) d.data()['readingKey'] as String};
  }

  // What to tell the user after a save, e.g. "Saved 3 books, 1 as an
  // extra copy" or "Already in this library, added another copy"
  static String savedMessage(({int added, int copies}) result) {
    final (:added, :copies) = result;
    String books(int n) => n == 1 ? '1 book' : '$n books';

    if (copies == 0) return 'Saved ${books(added)}';
    if (added == 0) {
      return copies == 1
          ? 'Already in this library, added another copy'
          : 'Already in this library, added ${books(copies)} as extra copies';
    }
    final extra = copies == 1
        ? '1 as an extra copy'
        : '$copies as extra copies';
    return 'Saved ${books(added + copies)}, $extra';
  }

  // The library's books, only public ones for viewers. The rules turn away
  // a viewer's query that could return a private book, so the filter is
  // needed, not just tidy.
  Query<Map<String, dynamic>> _books(String libraryId, bool publicOnly) {
    final books = _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books');
    return publicOnly
        ? books.where('visibility', isEqualTo: BookVisibility.public.name)
        : books;
  }

  // Watch books in a library. Each book remembers this library, so it can
  // be found again by its full path (libraries/{libraryId}/books/{id}).
  Stream<List<BookModel>> watchBooks(
    String libraryId, {
    required int limit,
    required bool publicOnly,
  }) {
    return _books(libraryId, publicOnly)
        .orderBy('addedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => BookModel.fromMap(
                  doc.id,
                  doc.data(),
                ).copyWith(libraryId: libraryId),
              )
              .toList(),
        );
  }

  // Newest books whose title, subtitle or author has a word starting with token
  Stream<List<BookModel>> searchBooks(
    String libraryId,
    String token, {
    required bool publicOnly,
    int limit = 50,
  }) {
    return _books(libraryId, publicOnly)
        .where('searchTokens', arrayContains: token)
        .orderBy('addedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BookModel.fromMap(
                  d.id,
                  d.data(),
                ).copyWith(libraryId: libraryId),
              )
              .toList(),
        );
  }

  // Deletes every book in the library, then the library itself.
  // Books go first because their rules check the library's members.
  Future<void> deleteLibrary(String libraryId) async {
    final libraryRef = _db.collection('libraries').doc(libraryId);

    // A batch holds at most 500 writes
    while (true) {
      final page = await libraryRef.collection('books').limit(400).get();
      if (page.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await libraryRef.delete();
  }

  // Remove one copy of a book, deleting the doc when it was the last copy
  Future<void> deleteBook(String libraryId, String bookId) async {
    final libraryRef = _db.collection('libraries').doc(libraryId);
    final bookRef = libraryRef.collection('books').doc(bookId);

    final snap = await bookRef.get();

    if (!snap.exists) return;

    final copies = (snap.data()?['noOfCopies'] as num?)?.toInt() ?? 1;

    final batch = _db.batch();

    if (copies > 1) {
      // If more than one book, just reduce counts
      batch.update(bookRef, {'noOfCopies': FieldValue.increment(-1)});
      batch.update(libraryRef, {'bookCount': FieldValue.increment(-1)});
    } else {
      // If a single book, delete it then update countsfinal
      batch.delete(bookRef);
      batch.update(libraryRef, {
        'bookCount': FieldValue.increment(-1),
        'uniqueCount': FieldValue.increment(-1),
      });
    }
    await batch.commit();
  }

  // Owner removing someone, or a member leaving with their own uid
  Future<void> removeMember(String libraryId, String uid) {
    return _db.collection('libraries').doc(libraryId).update({
      'members': FieldValue.arrayRemove([uid]),
      'editors': FieldValue.arrayRemove([uid]),
      'updatedAt': Timestamp.now(),
    });
  }

  //
  Future<void> setEditor(String libraryId, String uid, bool isEditor) {
    return _db.collection('libraries').doc(libraryId).update({
      'editors': isEditor
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),

      'updatedAt': Timestamp.now(),
    });
  }

  // Saves how the copy was acquired; empty text clears it
  Future<void> updateAcquisition(
    String libraryId,
    String bookId,
    String? text,
  ) async {
    final cleaned = text?.trim();

    final libraryRef = _db.collection('libraries').doc(libraryId);
    final bookRef = libraryRef.collection('books').doc(bookId);

    await bookRef.update({
      'acquisition': cleaned == null || cleaned.isEmpty ? null : cleaned,
    });
  }

  Future<void> updateOriginalLanguage(
    String libraryId,
    String bookId,
    String? code,
  ) async {
    final bookRef = _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
        .doc(bookId);

    await bookRef.update({'originalLanguage': code});
  }

  // Adding books merges copies by ISBN, so two books in one library can't
  // share one. Two results at most: one of them may be this same book.
  Future<void> updateIsbn(
    String libraryId,
    String bookId,
    String? isbn,
  ) async {
    final books = _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books');

    if (isbn != null) {
      final same = await books.where('isbn', isEqualTo: isbn).limit(2).get();
      if (same.docs.any((d) => d.id != bookId)) {
        throw Exception('Another book in this library already has this ISBN');
      }
    }

    await books.doc(bookId).update({'isbn': isbn});
  }

  // Private books are hidden from viewers; only editors can change this
  Future<void> updateVisibility(
    String libraryId,
    String bookId,
    BookVisibility visibility,
  ) {
    return _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
        .doc(bookId)
        .update({'visibility': visibility.name});
  }

  // One book, live; null once it's deleted
  // Every edition of one book in a library, live. Capped because a shelf
  // rarely holds more than a couple of editions of the same book.
  Stream<List<BookModel>> watchEditions(
    String libraryId,
    String readingKey, {
    required bool publicOnly,
  }) {
    return _books(libraryId, publicOnly)
        .where('readingKey', isEqualTo: readingKey)
        .limit(10)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BookModel.fromMap(
                  d.id,
                  d.data(),
                ).copyWith(libraryId: libraryId),
              )
              .toList(),
        );
  }

  // One saved book, live; null once it's deleted
  Stream<BookModel?> watchBook(String libraryId, String bookId) {
    final libraryRef = _db.collection('libraries').doc(libraryId);

    return libraryRef.collection('books').doc(bookId).snapshots().map((snap) {
      if (!snap.exists) return null;

      return BookModel.fromMap(
        snap.id,
        snap.data()!,
      ).copyWith(libraryId: libraryId);
    });
  }
}
