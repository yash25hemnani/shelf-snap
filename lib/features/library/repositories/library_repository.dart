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

  // Watch books in a library. Each book remembers this library, so it can
  // be found again by its full path (libraries/{libraryId}/books/{id}).
  Stream<List<BookModel>> watchBooks(String libraryId, {required int limit}) {
    return _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
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
    int limit = 50,
  }) {
    return _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
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

  // One book, live; null once it's deleted
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
