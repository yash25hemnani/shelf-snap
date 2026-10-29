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

  // Every read of every book, for stats. Each read comes with its book's
  // readingKey, since ReadModel doesn't store it.
  Stream<List<({String readingKey, ReadModel read})>> watchAllReads(
    String userId,
  ) {
    return _db
        .collectionGroup('reads')
        .where('uid', isEqualTo: userId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => (
                  readingKey: doc.reference.parent.parent!.id,
                  read: ReadModel.fromMap(doc.id, doc.data()),
                ),
              )
              .toList(),
        );
  }

  Stream<List<ReadingLogModel>> searchLogs(
    String userId,
    String token, {
    BookStatus? status,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _logs(
      userId,
    ).where('searchTokens', arrayContains: token);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ReadingLogModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<ReadModel>> watchReads(String userId, String readingKey) {
    return _reads(userId, readingKey)
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ReadModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Deletes a book's log and every read. Firestore doesn't delete
  // subcollections with their parent, so each read is deleted too.
  // A batch removes them all together, or none if it fails.
  Future<void> deleteLog(String readingKey, String userId) async {
    final logRef = _logs(userId).doc(readingKey);
    final readsSnap = await _reads(userId, readingKey).get();

    final batch = _db.batch();
    for (final doc in readsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(logRef);

    await batch.commit();
  }

  // Moves a book to [next], creating its log and read when needed.
  // Moving a reading or paused book back to want to read deletes its read;
  // a finished or DNF book can't go back, and nothing is saved.
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
          pageCount: log.pageCount,
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
        // Back to want to read: the book wasn't really started, so the
        // read is deleted. An ended read is history and stays.
        if (nextStatus == BookStatus.wantToRead) {
          if (!readModel.isActive) return false; // blocked

          tx.delete(readDoc!.reference);
          tx.set(
            logRef,
            log.copyWith(status: nextStatus, clearLatestRead: true).toMap(),
          );
          return true;
        }

        // When model is not null
        final changed = readModel.withStatus(nextStatus);
        if (identical(changed, readModel)) return false; // blocked
        // Takes the log's page count, so a finish keeps the count it ended at
        final updatedModel = changed.copyWith(pageCount: log.pageCount);

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

  // Sets the book's page count on the log, for books Google Books had none for.
  // An active read gets it too; ended reads keep the count they had.
  Future<void> updatePageCount(
    int pageCount,
    String readingKey,
    String userId,
  ) async {
    if (pageCount <= 0) throw ArgumentError('Invalid page count: $pageCount');

    final logRef = _logs(userId).doc(readingKey);
    final reads = _reads(userId, readingKey);

    await _db.runTransaction((tx) async {
      final logDoc = await tx.get(logRef);
      if (!logDoc.exists) return;

      final log = ReadingLogModel.fromMap(logDoc.id, logDoc.data()!);
      if (log.pageCount == pageCount) return; // no change

      // Reads must all happen before the first write in a transaction
      final latestReadId = log.latestRead?.id;
      final readDoc = latestReadId == null || !log.hasActiveRead
          ? null
          : await tx.get(reads.doc(latestReadId));

      var updatedLog = log.copyWith(pageCount: pageCount);

      if (readDoc != null && readDoc.exists) {
        final read = ReadModel.fromMap(
          readDoc.id,
          readDoc.data()!,
        ).copyWith(pageCount: pageCount);
        tx.update(readDoc.reference, read.toMap());
        updatedLog = updatedLog.copyWith(latestRead: read);
      }

      tx.update(logRef, updatedLog.toMap());
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

      final changed = readModel.withProgress(value, unit, log.pageCount);
      if (identical(changed, readModel)) return; // ended read or no change
      // Also fills it in on reads saved before reads had a page count
      final updatedModel = changed.copyWith(pageCount: log.pageCount);

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

  Future<void> startAgain(String readingKey, String userId) async {
    final logRef = _logs(userId).doc(readingKey);
    final reads = _reads(userId, readingKey);

    await _db.runTransaction((tx) async {
      final logDoc = await tx.get(logRef);
      if (!logDoc.exists) return;
      final log = ReadingLogModel.fromMap(logDoc.id, logDoc.data()!);

      // Only after an ended read
      final latest = log.latestRead;
      if (latest == null || latest.isActive) return;

      final readRef = reads.doc(); // new id
      final newRead = ReadModel(
        id: readRef.id,
        userId: userId,
        pageCount: log.pageCount,
      );

      tx.set(readRef, newRead.toMap());
      tx.update(
        logRef,
        log.copyWith(status: newRead.status, latestRead: newRead).toMap(),
      );
    });
  }

  Future<void> addPreviousRead(
    ReadDate? start,
    ReadDate end,
    String readingKey,
    String userId,
  ) async {
    final logRef = _logs(userId).doc(readingKey);
    final readRef = _reads(userId, readingKey).doc();

    final emptyModel = ReadModel(
      id: readRef.id,
      userId: userId,
      status: BookStatus.finished,
    );

    final read = emptyModel.withDates(start, end);
    // withDates returns the same model when the dates break a rule
    if (identical(read, emptyModel)) throw ArgumentError('Invalid dates');

    await _db.runTransaction((tx) async {
      final logDoc = await tx.get(logRef);
      if (!logDoc.exists) return;

      final log = ReadingLogModel.fromMap(logDoc.id, logDoc.data()!);
      final saved = read.copyWith(pageCount: log.pageCount);

      tx.set(readRef, saved.toMap());

      // A want to read book has no read yet, so this one becomes the latest.
      // Otherwise the current read stays the main one.
      if (log.latestRead == null) {
        tx.update(
          logRef,
          log.copyWith(status: saved.status, latestRead: saved).toMap(),
        );
      }
    });
  }

  Future<void> updateReadDates(
    ReadDate? start,
    ReadDate? end,
    String readId,
    String readingKey,
    String userId,
  ) async {
    final readRef = _reads(userId, readingKey).doc(readId);

    await _db.runTransaction((tx) async {
      final readDoc = await tx.get(readRef);
      if (!readDoc.exists) return;

      final readModel = ReadModel.fromMap(readDoc.id, readDoc.data()!);

      final updatedModel = readModel.withDates(start, end);

      if (identical(readModel, updatedModel)) return; // invalid or no change

      tx.update(readRef, updatedModel.toMap());
    });
  }

  // Deletes one read from the history. The latest read is skipped,
  // since the log would point at a read that's gone.
  Future<void> deletePastRead(
    String readId,
    String readingKey,
    String userId,
  ) async {
    final logRef = _logs(userId).doc(readingKey);

    await _db.runTransaction((tx) async {
      final logDoc = await tx.get(logRef);
      if (!logDoc.exists) return;

      final log = ReadingLogModel.fromMap(logDoc.id, logDoc.data()!);
      if (log.latestRead?.id == readId) return;

      tx.delete(_reads(userId, readingKey).doc(readId));
    });
  }
}
