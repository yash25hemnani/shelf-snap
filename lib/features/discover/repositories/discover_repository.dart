import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

class DiscoverRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _discovered(String userId) =>
      _db.collection('users').doc(userId).collection('discovered');

  DocumentReference<Map<String, dynamic>> _settings(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc(DiscoverSettingsModel.docId);

  // The reader's genres and place; empty settings when the doc doesn't exist
  Stream<DiscoverSettingsModel> watchSettings(String userId) {
    return _settings(
      userId,
    ).snapshots().map((doc) => DiscoverSettingsModel.fromMap(doc.data()));
  }

  // Saves the whole settings doc. The UI builds it with copyWith / withPlace
  // from the settings it's already showing, so no read is needed here.
  Future<void> saveSettings(
    String userId,
    DiscoverSettingsModel settings,
  ) async {
    try {
      await _settings(userId).set(settings.toMap());
    } catch (e) {
      throw Exception('Could not save your Discover settings');
    }
  }

  // Discovered books, most recently seen first. Firestore allows one
  // arrayContains per query, so with both filters the genre goes to
  // Firestore and the place is checked here.
  // Needs composite indexes: genres CONTAINS + lastSeenAt DESC,
  // places CONTAINS + lastSeenAt DESC.
  Stream<List<DiscoveredBookModel>> watchDiscovered(
    String userId, {
    Genre? genre,
    String? place,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _discovered(userId);
    if (genre != null) {
      query = query.where('genres', arrayContains: genre.name);
    } else if (place != null) {
      query = query.where('places', arrayContains: place);
    }

    return query
        .orderBy('lastSeenAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final books = snap.docs
              .map((doc) => DiscoveredBookModel.fromMap(doc.id, doc.data()))
              .toList();
          if (genre == null || place == null) return books;
          return books.where((b) => b.places.contains(place)).toList();
        });
  }

  // One discovered book, for the detail page; null when it was removed
  Stream<DiscoveredBookModel?> watchBook(String userId, String readingKey) {
    return _discovered(userId)
        .doc(readingKey)
        .snapshots()
        .map(
          (doc) => doc.exists
              ? DiscoveredBookModel.fromMap(doc.id, doc.data()!)
              : null,
        );
  }

  // Saves one scan's books in a batch, merged into any earlier sighting.
  // A batch (not a transaction) so it still queues offline, which matters
  // at a crowded book fair. [place] null leaves the places untouched.
  Future<void> saveScan(
    String userId,
    List<DiscoveredBookModel> books, {
    String? place,
  }) async {
    if (books.isEmpty) return;

    final batch = _db.batch();
    for (final book in books) {
      final data = book.toMap()
        ..remove('lastPlace')
        ..remove('places')
        ..['seenCount'] = FieldValue.increment(1)
        ..['lastSeenAt'] = FieldValue.serverTimestamp();

      // An empty list means the model didn't know the book this time, so
      // genres from an earlier scan are kept
      if (book.genres.isEmpty) data.remove('genres');

      if (place != null) {
        data['lastPlace'] = place;
        data['places'] = FieldValue.arrayUnion([place]);
      }

      batch.set(
        _discovered(userId).doc(book.id),
        data,
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Could not save the books you found');
    }
  }

  Future<void> deleteBook(String userId, String readingKey) async {
    try {
      await _discovered(userId).doc(readingKey).delete();
    } catch (e) {
      throw Exception('Could not remove this book');
    }
  }
}
