import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/reading/models/read_date.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

class ReadingLogRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logs(String userId) =>
      _db.collection('users').doc(userId).collection('readingLogs');

  CollectionReference<Map<String, dynamic>> _reads(
    String userId,
    String readingKey,
  ) => _logs(userId).doc(readingKey).collection('reads');

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
  // Filtering by status needs a composite index: status + updatedAt.
  Stream<List<ReadingLogModel>> watchLogs(String userId, {BookStatus? status}) {
    Query<Map<String, dynamic>> query = _logs(userId);
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

  // Deletes a book's log and its read. Firestore doesn't delete
  // subcollections with their parent, so the read goes first.
  Future<void> deleteLog(String readingKey, String userId) async {
    final logRef = _logs(userId).doc(readingKey);

    await _db.runTransaction((tx) async {
      final logDoc = await tx.get(logRef);
      if (!logDoc.exists) return;

      final readId = logDoc.data()!['latestReadId'] as String?;
      if (readId != null) {
        tx.delete(_reads(userId, readingKey).doc(readId));
      }
      tx.delete(logRef);
    });
  }

  // Moves a book to [next], creating its log and read when needed.
  // Moving back to want to read once a read exists is blocked and does nothing.
  // Returns true when something was saved.
  Future<bool> updateStatus(
    BookStatus nextStatus,
    BookModel book,
    String userId,
  ) async {
    final readingKey = book.readingKey;

    if (readingKey == null) return false;

    final logRef = _logs(userId).doc(readingKey);
    final reads = _reads(userId, readingKey);

    return _db.runTransaction<bool>((tx) async {
      final logDoc = await tx.get(logRef);

      // New log or existing
      final log = logDoc.exists
          ? ReadingLogModel.fromMap(logDoc.id, logDoc.data()!)
          : ReadingLogModel(
              id: readingKey,
              bookId: book.id,
              title: book.title,
              authors: book.authors,
              coverUrl: book.coverUrl,
              pageCount: book.pageCount,
            );

      final latestReadId = log.latestRead?.id;

      final readDoc = latestReadId == null
          ? null
          : await tx.get(reads.doc(latestReadId));

      final readModel = readDoc != null && readDoc.exists
          ? ReadModel.fromMap(readDoc.id, readDoc.data()!)
          : null;

      // Same status, do nothing and return
      if (logDoc.exists && log.status == nextStatus) return false;

      // When model is null
      if (readModel == null) {
        // Want to read is just status on the log
        if (nextStatus == BookStatus.wantToRead) {
          tx.set(logRef, log.copyWith(status: nextStatus).toMap());

          return true;
        }

        // Anything else, starts the first read
        final readRef = reads.doc(); // new id
        // The id is set now so the log's copy can save it
        final newRead = ReadModel(
          id: readRef.id,
          userId: userId,
        ).withStatus(nextStatus);

        // Update reads
        tx.set(readRef, newRead.toMap());

        // Update logs
        tx.set(
          logRef,
          log.copyWith(status: nextStatus, latestRead: newRead).toMap(),
        );

        return true;
      } else {
        // When model is not null
        final updatedModel = readModel.withStatus(nextStatus);
        if (identical(updatedModel, readModel)) return false; // blocked

        // Save the changed read over the old one, and its copy on the log
        tx.update(readDoc!.reference, updatedModel.toMap());
        tx.update(
          logRef,
          log.copyWith(status: nextStatus, latestRead: updatedModel).toMap(),
        );
        return true;
      }
    });
  }

  // Saves the current read's progress: a page or a percent
  Future<void> updateProgess(
    int value,
    ProgressUnit unit,
    String readingKey,
    String userId,
  ) async {
    final logRef = _logs(userId).doc(readingKey);
    final reads = _reads(userId, readingKey);

    await _db.runTransaction((tx) async {
      // Only an existing log can have progess
      final logDoc = await tx.get(logRef);
      if (!logDoc.exists) return;

      // get the log
      final log = ReadingLogModel.fromMap(logDoc.id, logDoc.data()!);

      // Want to read has no read, so there's nothing to update
      final latestReadId = log.latestRead?.id;
      if (latestReadId == null) return;

      final readDoc = await tx.get(reads.doc(latestReadId));
      if (!readDoc.exists) return;

      // Get the read model
      final readModel = ReadModel.fromMap(readDoc.id, readDoc.data()!);

      final updatedModel = readModel.withProgress(value, unit, log.pageCount);
      if (identical(updatedModel, readModel)) return; // ended read or no change

      tx.update(readDoc.reference, updatedModel.toMap());

      // copy to the log
      tx.update(logRef, log.copyWith(latestRead: updatedModel).toMap());
    });
  }

  // Saves the current read's start and end dates; either can be partial
  Future<void> updateDates(
    ReadDate? start,
    ReadDate? end,
    String readingKey,
    String userId,
  ) async {
    final logRef = _logs(userId).doc(readingKey);
    final reads = _reads(userId, readingKey);

    await _db.runTransaction((tx) async {
      // Only an existing log can have dates
      final logDoc = await tx.get(logRef);
      if (!logDoc.exists) return;

      // get the log
      final log = ReadingLogModel.fromMap(logDoc.id, logDoc.data()!);

      // Want to read has no read, so there's nothing to update
      final latestReadId = log.latestRead?.id;
      if (latestReadId == null) return;

      final readDoc = await tx.get(reads.doc(latestReadId));
      if (!readDoc.exists) return;

      // Get the read model
      final readModel = ReadModel.fromMap(readDoc.id, readDoc.data()!);

      final updatedModel = readModel.withDates(start, end);
      if (identical(updatedModel, readModel)) return; // invalid or no change

      tx.update(readDoc.reference, updatedModel.toMap());

      // copy to the log
      tx.update(logRef, log.copyWith(latestRead: updatedModel).toMap());
    });
  }
}
