import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/models/join_request.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

class LibraryRepository {
  final _db = FirebaseFirestore.instance;

  // Create a library, returning its generated id
  DocumentReference<Map<String, dynamic>> _handleDoc(String handle) =>
      _db.collection('libraryHandles').doc(handle);

  // Creates the library, and reserves its handle in the same batch so two
  // libraries can't end up with one web address
  Future<String> createLibrary(LibraryModel library) async {
    final data = library.toMap();
    // Ensure owner in members
    data["members"] = {...library.members, library.ownerId}.toList();
    data["editors"] = {library.ownerId}.toList();

    final ref = _db.collection("libraries").doc();
    final batch = _db.batch()..set(ref, data);
    if (library.handle != null) {
      batch.set(_handleDoc(library.handle!), {
        'libraryId': ref.id,
        'ownerId': library.ownerId,
      });
    }
    await batch.commit();
    return ref.id;
  }

  // Only the fields the edit form changes, so counts and members are untouched.
  // A new handle swaps the reservation: old one freed, new one taken.
  Future<void> updateLibrary(LibraryModel library, {String? oldHandle}) {
    final batch = _db.batch()
      ..update(_db.collection('libraries').doc(library.id), {
        'name': library.name,
        'description': library.description,
        'banner': library.banner,
        'access': library.access.name,
        'handle': library.handle,
        'updatedAt': Timestamp.now(),
      });

    if (library.handle != oldHandle) {
      if (oldHandle != null) batch.delete(_handleDoc(oldHandle));
      if (library.handle != null) {
        batch.set(_handleDoc(library.handle!), {
          'libraryId': library.id,
          'ownerId': library.ownerId,
        });
      }
    }
    return batch.commit();
  }

  // True when another library already uses this handle
  Future<bool> isHandleTaken(String handle, {String? libraryId}) async {
    final snap = await _handleDoc(handle).get();
    return snap.exists && snap.data()?['libraryId'] != libraryId;
  }

  // Most recently active public libraries. Capped, since anyone can list
  // them; the access filter is also what lets the rules allow the query.
  Stream<List<LibraryModel>> watchPublicLibraries({int limit = 20}) {
    return _db
        .collection('libraries')
        .where('access', isEqualTo: LibraryAccess.public.name)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LibraryModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
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
  // [handle] is freed along with the library
  Future<void> deleteLibrary(String libraryId, {String? handle}) async {
    final libraryRef = _db.collection('libraries').doc(libraryId);

    // A batch holds at most 500 writes. Join requests go too, or they'd
    // stay in the owner's notifications after the library is gone.
    for (final sub in ['books', 'joinRequests']) {
      while (true) {
        final page = await libraryRef.collection(sub).limit(400).get();
        if (page.docs.isEmpty) break;

        final batch = _db.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    final batch = _db.batch()..delete(libraryRef);
    if (handle != null) batch.delete(_handleDoc(handle));
    await batch.commit();
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

  CollectionReference<Map<String, dynamic>> _joinRequests(String libraryId) =>
      _db.collection('libraries').doc(libraryId).collection('joinRequests');

  // Asks the owner of a public library to let this user in. The doc id is
  // the uid, so asking twice can't make two requests.
  Future<void> requestToJoin(
    LibraryModel library,
    String uid,
    String username,
  ) {
    final request = JoinRequest(
      uid: uid,
      libraryId: library.id!,
      username: username,
      ownerId: library.ownerId,
      libraryName: library.name,
      createdAt: DateTime.now(),
    );
    return _joinRequests(library.id!).doc(uid).set({
      ...request.toMap(),
      // Must equal request.time in the rules
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // The requester cancelling, or the owner declining
  Future<void> deleteJoinRequest(String libraryId, String uid) =>
      _joinRequests(libraryId).doc(uid).delete();

  // True while this user has a request waiting on the library
  Stream<bool> watchHasRequested(String libraryId, String uid) =>
      _joinRequests(libraryId).doc(uid).snapshots().map((snap) => snap.exists);

  // Requests waiting on one library, oldest first. Capped, since the owner
  // works through them and they don't pile up.
  Stream<List<JoinRequest>> watchJoinRequests(
    String libraryId, {
    int limit = 50,
  }) {
    return _joinRequests(libraryId)
        .orderBy('createdAt')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(JoinRequest.fromDoc).toList());
  }

  // Requests waiting on every library this user owns, oldest first. No
  // orderBy, so a single-field index is enough; sorted here instead.
  Stream<List<JoinRequest>> watchOwnerJoinRequests(
    String ownerId, {
    int limit = 50,
  }) {
    return _db
        .collectionGroup('joinRequests')
        .where('ownerId', isEqualTo: ownerId)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(JoinRequest.fromDoc).toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  // Adds the requester as a member and clears the request in one batch,
  // so nobody is left a member with a request still waiting
  Future<void> approveJoinRequest(String libraryId, String uid) {
    final batch = _db.batch()
      ..update(_db.collection('libraries').doc(libraryId), {
        'members': FieldValue.arrayUnion([uid]),
        'updatedAt': Timestamp.now(),
      })
      ..delete(_joinRequests(libraryId).doc(uid));
    return batch.commit();
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
  Future<void> updateIsbn(String libraryId, String bookId, String? isbn) async {
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
