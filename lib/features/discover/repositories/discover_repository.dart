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

  // Most recently seen books with a title, subtitle or author word that
  // starts with [token]. Needs a composite index:
  // searchTokens CONTAINS + lastSeenAt DESC.
  Stream<List<DiscoveredBookModel>> searchDiscovered(
    String userId,
    String token, {
    int limit = 50,
  }) {
    return _discovered(userId)
        .where('searchTokens', arrayContains: token)
        .orderBy('lastSeenAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => DiscoveredBookModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // One-time fill-in for books saved before search existed. Firestore
  // can't query for a missing field, so it reads every book once, then sets
  // searchIndexed in the settings so it never runs again.
  // Reads from the server only: a half-filled offline cache would set the
  // flag too early.
  Future<void> indexForSearch(String userId) async {
    try {
      final snap = await _discovered(
        userId,
      ).get(const GetOptions(source: Source.server));
      final missing = snap.docs
          .where((doc) => doc.data()['searchTokens'] == null)
          .toList();

      // A batch takes at most 500 writes
      for (var i = 0; i < missing.length; i += 500) {
        final batch = _db.batch();
        for (final doc in missing.skip(i).take(500)) {
          final item = DiscoveredBookModel.fromMap(doc.id, doc.data());
          batch.update(doc.reference, {'searchTokens': item.searchTokens});
        }
        await batch.commit();
      }

      // update() keeps any genre or place change made meanwhile; a
      // missing settings doc is created with the defaults
      final settingsRef = _settings(userId);
      final settingsDoc = await settingsRef.get();
      if (settingsDoc.exists) {
        await settingsRef.update({
          'searchIndexed': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await settingsRef.set(
          const DiscoverSettingsModel(searchIndexed: true).toMap(),
        );
      }
    } catch (e) {
      throw Exception('Could not prepare search');
    }
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

  // Removes several books at once. A batch takes 500 writes, and the
  // selection can't be bigger than the loaded list.
  Future<void> deleteBooks(String userId, Iterable<String> readingKeys) async {
    final batch = _db.batch();
    for (final key in readingKeys) {
      batch.delete(_discovered(userId).doc(key));
    }

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Could not remove these books');
    }
  }

  // Tags books with a place without marking them as seen again, so they
  // keep their spot in the list. The caller skips books already holding
  // the most places, or the rules reject the whole batch.
  Future<void> addPlace(
    String userId,
    Iterable<String> readingKeys,
    String place,
  ) async {
    final batch = _db.batch();
    for (final key in readingKeys) {
      batch.update(_discovered(userId).doc(key), {
        'lastPlace': place,
        'places': FieldValue.arrayUnion([place]),
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Could not add the place');
    }
  }
}
