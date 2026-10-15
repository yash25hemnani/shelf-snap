import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/core/models/book_result.dart';
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
}
