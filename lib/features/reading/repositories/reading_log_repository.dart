import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

class ReadingLogRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logs(String userId) =>
      _db.collection('users').doc(userId).collection('readingLogs');

  Future<void> updateBookStatus(
    BookStatus status,
    BookModel book,
    String userId,
  ) async {
    // Local, so Dart knows it's non-null after the check
    final readingKey = book.readingKey;
    if (readingKey == null) return;

    final logs = _logs(userId);

    // One unit: if another save changes the log between the read and the
    // write, Firestore reruns this with fresh data. All reads come first.
    await _db.runTransaction((tx) async {
      var doc = await tx.get(logs.doc(readingKey));

      // No log yet: create one with the key as its id.
      // Search books have no id, so bookId stays null.
      if (!doc.exists) {
        final newLog = ReadingLogModel(
          readingId: readingKey,
          bookId: book.id,
          title: book.title,
          authors: book.authors,
          coverUrl: book.coverUrl,
          pageCount: book.pageCount,
          status: status,
        );
        tx.set(doc.reference, newLog.toMap());
        return;
      }

      // Follow aliasFor to the real log; the cap stops A → B → A loops
      for (var hops = 0; hops < 5; hops++) {
        final aliasFor = doc.data()?['aliasFor'] as String?;
        if (aliasFor == null || aliasFor.isEmpty) break;
        doc = await tx.get(logs.doc(aliasFor));
      }
      if (!doc.exists) return; // alias pointed to a deleted log

      tx.update(doc.reference, {
        'status': status.name,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  // The log for one book, keyed by its readingKey; null when there's none
  Stream<ReadingLogModel?> watchLog(String userId, String readingKey) {
    return _logs(userId)
        .doc(readingKey)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? ReadingLogModel.fromMap(doc.id, doc.data()!) : null,
        );
  }

  // The user's logs, most recently changed first; [status] null means all.
  // Alias docs only point to another log, so they're left out.
  // Needs composite indexes: aliasFor + updatedAt, and
  // aliasFor + status + updatedAt.
  Stream<List<ReadingLogModel>> watchLogs(String userId, {BookStatus? status}) {
    Query<Map<String, dynamic>> query = _logs(
      userId,
    ).where('aliasFor', isNull: true);
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ReadingLogModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
