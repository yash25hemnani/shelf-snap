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

  // Add a book to the libray, or one more copy if the edition is already there
  Future<void> addBook(String libraryId, BookModel book) async {
    final libraryRef = _db.collection('libraries').doc(libraryId);
    final existingRef = await findBookInLibrary(libraryId, book);

    final batch = _db.batch();

    if (existingRef != null) {
      // Another copy of the same edition, uniqueCount stays the same
      batch.update(existingRef, {'noOfCopies': FieldValue.increment(1)});
      batch.update(libraryRef, {'bookCount': FieldValue.increment(1)});
    } else {
      final bookRef = libraryRef
          .collection('books')
          .doc(); // new id, nothing written yet

      batch.set(bookRef, book.toMap());
      batch.update(libraryRef, {
        'bookCount': FieldValue.increment(1),
        'uniqueCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  // Add multiple books to a library
  Future<void> addBooks(String libraryId, List<BookModel> books) async {
    final libraryRef = _db.collection('libraries').doc(libraryId);
    final batch = _db.batch();
    final now = DateTime.now();

    var unique = 0;

    for (final book in books) {
      // Check if book in library
      final existingRef = await findBookInLibrary(libraryId, book);

      if (existingRef != null) {
        batch.update(existingRef, {'noOfCopies': FieldValue.increment(1)});
        continue;
      }

      final bookRef = libraryRef.collection("books").doc();
      batch.set(bookRef, book.copyWith(addedAt: now).toMap());
      unique++;
    }

    // Every book is one more physical copy, only new docs are new editions
    batch.update(libraryRef, {
      'bookCount': FieldValue.increment(books.length),
      'uniqueCount': FieldValue.increment(unique),
    });

    await batch.commit();
  }

  // Watch books in a library. Each book remembers this library, so it can
  // be found again by its full path (libraries/{libraryId}/books/{id}).
  Stream<List<BookModel>> watchBooks(String libraryId) {
    return _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
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

  // Delete a library
  Future<void> deleteLibrary(String libraryId) async {
    await _db.collection('libraries').doc(libraryId).delete();
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
}
