import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/models/book_result.dart';
import 'package:shelf_snap/models/library_model.dart';

class LibraryRepository {
  final _db = FirebaseFirestore.instance;

  // Create a library
  Future<void> createLibrary(LibraryModel library) async {
    final data = library.toMap();
    // Ensure owner in members
    data["members"] = {...library.members, library.ownerId}.toList();
    await _db.collection("libraries").add(library.toMap());
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

  // Add a book to the libray
  Future<void> addBook(String libraryId, BookResult book) async {
    await _db
        .collection("libraries")
        .doc(libraryId)
        .collection("books")
        .add(book.toMap());

    // Accumulate genres
    await _db.doc('meta/genres').set({
      'list': FieldValue.arrayUnion(book.genres),
    }, SetOptions(merge: true));
  }

  // Watch books in a library
  Stream<List<BookResult>> watchBooks(String libraryId) {
    return _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookResult.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Delete a library
  Future<void> deleteLibrary(String libraryId) async {
    await _db.collection('libraries').doc(libraryId).delete();
  }

  // Delete a book
  Future<void> deleteBook(String libraryId, String bookId) async {
    await _db
        .collection('libraries')
        .doc(libraryId)
        .collection('books')
        .doc(bookId)
        .delete();
  }

  // Fetch genres
  Future<List<String>> fetchGenres() async {
    final doc = await _db.doc('meta/genres').get();
    return List<String>.from(doc['list'] ?? []);
  }
}
