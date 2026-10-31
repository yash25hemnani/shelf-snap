import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

// The message to show for a failed loan action. The repository's own
// checks read well as they are; Firebase errors get the fallback.
String loanErrorText(Object error, String fallback) =>
    (error is Exception && error is! FirebaseException)
    ? error.toString().replaceFirst('Exception: ', '')
    : fallback;

class LoanRepository {
  final _db = FirebaseFirestore.instance;

  Future<LibraryModel> _editableLibrary(String libraryId, String userId) async {
    final snap = await _db.collection('libraries').doc(libraryId).get();
    final data = snap.data();

    if (!snap.exists || data == null) throw Exception("Library not found.");

    final library = LibraryModel.fromMap(snap.id, data);

    if (!library.canEdit(userId)) {
      throw Exception("You do not have permission to manage this library");
    }

    return library;
  }

  // The user's requested, approved or lent loans on one book
  Query<Map<String, dynamic>> _openLoansFor(
    String libraryId,
    String bookId,
    String userId,
  ) {
    return _db
        .collection('loans')
        .where('borrowerId', isEqualTo: userId)
        .where('libraryId', isEqualTo: libraryId)
        .where('bookId', isEqualTo: bookId)
        .where(
          'status',
          whereIn: [
            LoanStatus.requested.name,
            LoanStatus.approved.name,
            LoanStatus.lent.name,
          ],
        );
  }

  // Borrower asks for a book; returns the new loan's id
  Future<String> requestLoan(LoanModel request, String userId) async {
    if (request.borrowerId != userId) {
      throw Exception("You can only request books for yourself.");
    }

    final snap = await _db.collection('libraries').doc(request.libraryId).get();

    final data = snap.data();

    if (!snap.exists || data == null) {
      throw Exception("Library does not exist.");
    }

    final library = LibraryModel.fromMap(snap.id, data);

    if (library.canEdit(userId)) {
      throw Exception("You can't borrow from a library you manage.");
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (request.collectOn != null && request.collectOn!.isBefore(today)) {
      throw Exception("Pick a collect date from today on.");
    }

    if (request.dueOn != null && request.dueOn!.isBefore(today)) {
      throw Exception("Pick a return date from today on.");
    }

    if (request.dueOn != null &&
        request.collectOn != null &&
        !request.dueOn!.isAfter(request.collectOn!)) {
      throw Exception("The return date must be after the collect date");
    }

    if (await hasActiveRequest(request.libraryId, request.bookId, userId)) {
      throw Exception("You've already requested this book.");
    }

    final note = request.requestNote?.trim();

    final loan = LoanModel(
      libraryId: request.libraryId,
      bookId: request.bookId,
      ownerId: library.ownerId,
      borrowerId: userId,
      bookTitle: request.bookTitle,
      coverUrl: request.coverUrl,
      borrowerName: request.borrowerName,
      libraryName: library.name,
      collectOn: request.collectOn,
      dueOn: request.dueOn,
      requestNote: note == null || note.isEmpty ? null : note,
    );

    final doc = await _db.collection('loans').add(loan.toMap());

    return doc.id;
  }

  // Borrower withdraws before the book is handed over
  Future<void> cancelLoan(String loanId, String userId) async {
    final ref = _db.collection('loans').doc(loanId);

    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);

      if (!snapshot.exists) {
        throw Exception("Loan not found");
      }

      final data = snapshot.data()!;

      if (data["borrowerId"] != userId) {
        throw Exception("Only the borrower can cancel this request.");
      }

      if (data["status"] != LoanStatus.requested.name &&
          data["status"] != LoanStatus.approved.name) {
        throw Exception("This request can no longer be cancelled.");
      }

      tx.update(ref, {'status': LoanStatus.cancelled.name});
    });
  }

  Future<void> approveLoan(
    String loanId,
    String userId, {
    DateTime? dueOn,
    String? responseNote,
  }) async {
    final ref = _db.collection('loans').doc(loanId);

    final snap = await ref.get();
    final data = snap.data();

    if (!snap.exists || data == null) throw Exception("Loan not found");

    final loan = LoanModel.fromMap(loanId, data);

    await _editableLibrary(loan.libraryId, userId);

    final note = responseNote?.trim();

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(ref);

      if (!fresh.exists || fresh.data() == null) {
        throw Exception("Loan not found");
      }

      final freshLoan = LoanModel.fromMap(fresh.id, fresh.data()!);

      if (freshLoan.status != LoanStatus.requested) {
        throw Exception("This request has already been answered.");
      }

      tx.update(ref, {
        'status': LoanStatus.approved.name,
        'respondedOn': Timestamp.now(),
        'dueOn': dueOn == null ? null : Timestamp.fromDate(dueOn),
        if (note != null && note.isNotEmpty) 'responseNote': note,
      });
    });
  }

  // Also allowed after approving, as long as the book wasn't handed over
  Future<void> rejectLoan(
    String loanId,
    String userId, {
    String? responseNote,
  }) async {
    final ref = _db.collection('loans').doc(loanId);

    final snap = await ref.get();
    final data = snap.data();

    if (!snap.exists || data == null) throw Exception("Loan not found");

    final loan = LoanModel.fromMap(loanId, data);

    await _editableLibrary(loan.libraryId, userId);

    final note = responseNote?.trim();

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(ref);

      if (!fresh.exists || fresh.data() == null) {
        throw Exception("Loan not found");
      }

      final freshLoan = LoanModel.fromMap(fresh.id, fresh.data()!);

      if (freshLoan.status != LoanStatus.requested &&
          freshLoan.status != LoanStatus.approved) {
        throw Exception("This request can no longer be rejected.");
      }

      tx.update(ref, {
        'status': LoanStatus.rejected.name,
        'respondedOn': Timestamp.now(),
        if (note != null && note.isNotEmpty) 'responseNote': note,
      });
    });
  }

  // The book is handed over. Takes one copy off the shelf, failing when
  // every copy is already out.
  Future<void> markLent(String loanId, String userId, {DateTime? dueOn}) async {
    final ref = _db.collection('loans').doc(loanId);

    final snap = await ref.get();
    final data = snap.data();

    if (!snap.exists || data == null) throw Exception("Loan not found");

    final loan = LoanModel.fromMap(loanId, data);

    await _editableLibrary(loan.libraryId, userId);

    final bookRef = _db
        .collection('libraries')
        .doc(loan.libraryId)
        .collection('books')
        .doc(loan.bookId);

    await _db.runTransaction((tx) async {
      final loanSnap = await tx.get(ref);
      final bookSnap = await tx.get(bookRef);

      if (!loanSnap.exists || loanSnap.data() == null) {
        throw Exception("Loan not found");
      }

      final currentLoan = LoanModel.fromMap(loanId, loanSnap.data()!);

      if (currentLoan.status != LoanStatus.approved) {
        throw Exception("Only approved requests can be lent");
      }

      if (!bookSnap.exists || bookSnap.data() == null) {
        throw Exception("This book is no longer in the library.");
      }

      final book = BookModel.fromMap(loan.bookId, bookSnap.data()!);

      final copies = book.noOfCopies;
      final lent = book.lentCount;

      if (lent >= copies) {
        throw Exception("All copies are already lent");
      }

      tx.update(ref, {
        'status': LoanStatus.lent.name,
        'lentOn': Timestamp.now(),
        if (dueOn != null) 'dueOn': Timestamp.fromDate(dueOn),
      });

      tx.update(bookRef, {'lentCount': FieldValue.increment(1)});
    });
  }

  // The copy is back on the shelf
  Future<void> markReturned(String loanId, String userId) async {
    final ref = _db.collection('loans').doc(loanId);

    final snap = await ref.get();
    final data = snap.data();

    if (!snap.exists || data == null) throw Exception("Loan not found");

    final loan = LoanModel.fromMap(loanId, data);

    await _editableLibrary(loan.libraryId, userId);

    final bookRef = _db
        .collection('libraries')
        .doc(loan.libraryId)
        .collection('books')
        .doc(loan.bookId);

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(ref);

      if (fresh.data()?['status'] != LoanStatus.lent.name) {
        throw Exception("This book isn't out on loan");
      }

      tx.update(ref, {
        'status': LoanStatus.returned.name,
        'returnedOn': Timestamp.now(),
      });

      tx.update(bookRef, {'lentCount': FieldValue.increment(-1)});
    });
  }

  // The copy is gone, so it leaves the library like deleteBook: one copy
  // fewer, or the whole book when it was the last copy
  Future<void> markLost(String loanId, String userId) async {
    final ref = _db.collection('loans').doc(loanId);

    final snap = await ref.get();
    final data = snap.data();

    if (!snap.exists || data == null) throw Exception("Loan not found");

    final loan = LoanModel.fromMap(loanId, data);

    await _editableLibrary(loan.libraryId, userId);

    final libraryRef = _db.collection('libraries').doc(loan.libraryId);
    final bookRef = libraryRef.collection('books').doc(loan.bookId);

    await _db.runTransaction((tx) async {
      // All reads before any writes
      final fresh = await tx.get(ref);
      final bookSnap = await tx.get(bookRef);

      if (fresh.data()?['status'] != LoanStatus.lent.name) {
        throw Exception("This book isn't out on loan");
      }

      tx.update(ref, {
        'status': LoanStatus.lost.name,
        'returnedOn': Timestamp.now(),
      });

      // Already removed from the library, so there's no copy to take off
      final bookData = bookSnap.data();
      if (bookData == null) return;

      final book = BookModel.fromMap(loan.bookId, bookData);

      if (book.noOfCopies > 1) {
        tx.update(bookRef, {
          'noOfCopies': FieldValue.increment(-1),
          'lentCount': FieldValue.increment(-1),
        });
        tx.update(libraryRef, {'bookCount': FieldValue.increment(-1)});
      } else {
        tx.delete(bookRef);
        tx.update(libraryRef, {
          'bookCount': FieldValue.increment(-1),
          'uniqueCount': FieldValue.increment(-1),
        });
      }
    });
  }

  // Null clears the due date
  Future<void> updateDueDate(
    String loanId,
    String userId,
    DateTime? dueOn,
  ) async {
    final ref = _db.collection('loans').doc(loanId);

    final snap = await ref.get();
    final data = snap.data();

    if (!snap.exists || data == null) throw Exception("Loan not found");

    final loan = LoanModel.fromMap(loanId, data);

    await _editableLibrary(loan.libraryId, userId);

    await _db.runTransaction((tx) async {
      final status = (await tx.get(ref)).data()?['status'];

      if (status != LoanStatus.approved.name &&
          status != LoanStatus.lent.name) {
        throw Exception("The due date can't be changed now");
      }

      tx.update(ref, {
        'dueOn': dueOn == null ? null : Timestamp.fromDate(dueOn),
      });
    });
  }

  // Newest first. Borrowed: the user's own requests. Lent: loans for
  // [libraryIds], the libraries the user manages. The rules make one get()
  // per library and allow 10 per query, so only the first 10 are covered.
  Stream<List<LoanModel>> watchLoans(
    LoanDirection direction,
    String userId, {
    List<String> libraryIds = const [],
  }) {
    Query<Map<String, dynamic>> query = _db.collection('loans');

    switch (direction) {
      case LoanDirection.borrowed:
        query = query.where('borrowerId', isEqualTo: userId);

      case LoanDirection.lent:
        // whereIn throws on an empty list
        if (libraryIds.isEmpty) return Stream.value(const []);
        query = query.where('libraryId', whereIn: libraryIds.take(10).toList());
    }

    return query
        .orderBy('requestedOn', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => LoanModel.fromMap(d.id, d.data())).toList(),
        );
  }

  // Requested, approved and lent loans for one book
  Stream<List<LoanModel>> watchBookLoans(String libraryId, String bookId) {
    return _db
        .collection('loans')
        .where('libraryId', isEqualTo: libraryId)
        .where('bookId', isEqualTo: bookId)
        .where(
          'status',
          whereIn: [
            LoanStatus.requested.name,
            LoanStatus.approved.name,
            LoanStatus.lent.name,
          ],
        )
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => LoanModel.fromMap(d.id, d.data())).toList(),
        );
  }

  // The user's open loan on this book, or null. Borrowers can't read other
  // people's loans, so this is what the book page uses for them.
  Stream<LoanModel?> watchMyBookLoan(
    String libraryId,
    String bookId,
    String userId,
  ) {
    return _openLoansFor(libraryId, bookId, userId)
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isEmpty
              ? null
              : LoanModel.fromMap(snap.docs.first.id, snap.docs.first.data()),
        );
  }

  // True when the user already has an open loan on this book
  Future<bool> hasActiveRequest(
    String libraryId,
    String bookId,
    String userId,
  ) async {
    final snap = await _openLoansFor(
      libraryId,
      bookId,
      userId,
    ).limit(1).get(); // limit(1) because we only need to know if one exists

    return snap.docs.isNotEmpty;
  }
}
