import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

class ReadingLogRepository {
  final _db = FirebaseFirestore.instance;

  Future<void> updateBookStatus(
    BookStatus status,
    BookModel book,
    String userId,
  ) async {
    // Local, so Dart knows it's non-null after the check
    final readingKey = book.readingKey;
    if (readingKey == null) return;

    final logs = _db.collection('users').doc(userId).collection('readingLogs');

    // Find if the log exists
    final snapshot = await logs
        .where('readingId', isEqualTo: readingKey)
        .limit(1)
        .get();

    // No log yet: create one with this status
    if (snapshot.docs.isEmpty) {
      // Search books have no id, so bookId stays null
      final newLog = ReadingLogModel(
        readingId: readingKey,
        bookId: book.id,
        title: book.title,
        authors: book.authors,
        coverUrl: book.coverUrl,
        pageCount: book.pageCount,
        status: status,
      );
      await logs.add(newLog.toMap());
      return;
    }

    // Follow aliasFor until we reach the real log.
    // The hop limit stops a loop like A → B → A from running forever.
    DocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs.first;

    for (var hops = 0; hops < 5; hops++) {
      final aliasFor = doc.data()?['aliasFor'] as String?;
      if (aliasFor == null || aliasFor.isEmpty) break;
      doc = await logs.doc(aliasFor).get();
    }

    if (!doc.exists) return; // alias pointed to a deleted log

    await doc.reference.update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Stream<ReadingLogModel?> watchLog(String userId, String readingKey) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('readingLogs')
        .where('readingId', isEqualTo: readingKey)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          return ReadingLogModel.fromMap(doc.id, doc.data());
        });
  }
}
