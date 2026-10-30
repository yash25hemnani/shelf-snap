import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

enum LoanStatus {
  requested,
  approved,
  rejected,
  cancelled,
  lent,
  returned,
  lost,
}

extension LoanStatusLabel on LoanStatus {
  String get label => switch (this) {
    LoanStatus.requested => 'Requested',
    LoanStatus.approved => 'Approved',
    LoanStatus.rejected => 'Rejected',
    LoanStatus.cancelled => 'Cancelled',
    LoanStatus.lent => 'Lent',
    LoanStatus.returned => 'Returned',
    LoanStatus.lost => 'Lost',
  };
}

// Which way a loan goes for the user: books they borrowed, or books lent
// out from libraries they manage
enum LoanDirection { borrowed, lent }

// One loan of a library book, from request to return: loans/{loanId}.
// Top-level so the borrower and the library's editors share one doc.
class LoanModel {
  final String? id; // null until saved
  final String libraryId;
  final String bookId;
  final String ownerId; // the library owner when the request was made
  final String borrowerId;
  final LoanStatus status;

  // Copies, so list rows need no extra reads
  final String bookTitle;
  final String? coverUrl;
  final String borrowerName;
  final String libraryName;

  final DateTime? requestedOn; // null until saved
  final DateTime? respondedOn; // approved or rejected
  final DateTime? lentOn; // handed over
  final DateTime? collectOn; // when the borrower wants to pick it up
  final DateTime? dueOn;
  final DateTime? returnedOn; // returned or lost

  final String? requestNote;
  final String? responseNote;

  const LoanModel({
    this.id,
    required this.libraryId,
    required this.bookId,
    required this.ownerId,
    required this.borrowerId,
    this.status = LoanStatus.requested,
    required this.bookTitle,
    this.coverUrl,
    required this.borrowerName,
    required this.libraryName,
    this.requestedOn,
    this.respondedOn,
    this.lentOn,
    this.collectOn,
    this.dueOn,
    this.returnedOn,
    this.requestNote,
    this.responseNote,
  });

  factory LoanModel.fromMap(String id, Map<String, dynamic> map) {
    return LoanModel(
      id: id,
      libraryId: map['libraryId'] as String? ?? '',
      bookId: map['bookId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      borrowerId: map['borrowerId'] as String? ?? '',
      status:
          LoanStatus.values.asNameMap()[map['status']] ?? LoanStatus.requested,
      bookTitle: map['bookTitle'] as String? ?? BookModel.unknownTitle,
      coverUrl: map['coverUrl'] as String?,
      borrowerName: map['borrowerName'] as String? ?? '',
      libraryName: map['libraryName'] as String? ?? '',
      requestedOn: (map['requestedOn'] as Timestamp?)?.toDate(),
      respondedOn: (map['respondedOn'] as Timestamp?)?.toDate(),
      lentOn: (map['lentOn'] as Timestamp?)?.toDate(),
      collectOn: (map['collectOn'] as Timestamp?)?.toDate(),
      dueOn: (map['dueOn'] as Timestamp?)?.toDate(),
      returnedOn: (map['returnedOn'] as Timestamp?)?.toDate(),
      requestNote: map['requestNote'] as String?,
      responseNote: map['responseNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    // No 'id': it's the doc id, so storing it would duplicate it
    'libraryId': libraryId,
    'bookId': bookId,
    'ownerId': ownerId,
    'borrowerId': borrowerId,
    'status': status.name,
    'bookTitle': bookTitle,
    'coverUrl': coverUrl,
    'borrowerName': borrowerName,
    'libraryName': libraryName,
    'requestedOn': Timestamp.fromDate(requestedOn ?? DateTime.now()),
    'respondedOn': respondedOn == null
        ? null
        : Timestamp.fromDate(respondedOn!),
    'lentOn': lentOn == null ? null : Timestamp.fromDate(lentOn!),
    'collectOn': collectOn == null ? null : Timestamp.fromDate(collectOn!),
    'dueOn': dueOn == null ? null : Timestamp.fromDate(dueOn!),
    'returnedOn': returnedOn == null ? null : Timestamp.fromDate(returnedOn!),
    'requestNote': requestNote,
    'responseNote': responseNote,
  };

  // Still waiting on someone: not yet answered, or the book is out
  bool get isActive =>
      status == LoanStatus.requested ||
      status == LoanStatus.approved ||
      status == LoanStatus.lent;

  bool get isOverdue =>
      status == LoanStatus.lent &&
      dueOn != null &&
      DateTime.now().isAfter(dueOn!);

  // A copy with the given fields changed. Passing null keeps the current
  // value, so use [clearDueOn] to remove the due date.
  LoanModel copyWith({
    LoanStatus? status,
    DateTime? respondedOn,
    DateTime? lentOn,
    DateTime? dueOn,
    bool clearDueOn = false,
    DateTime? returnedOn,
    String? responseNote,
  }) {
    return LoanModel(
      id: id,
      libraryId: libraryId,
      bookId: bookId,
      ownerId: ownerId,
      borrowerId: borrowerId,
      status: status ?? this.status,
      bookTitle: bookTitle,
      coverUrl: coverUrl,
      borrowerName: borrowerName,
      libraryName: libraryName,
      requestedOn: requestedOn,
      respondedOn: respondedOn ?? this.respondedOn,
      lentOn: lentOn ?? this.lentOn,
      collectOn: collectOn,
      dueOn: clearDueOn ? null : (dueOn ?? this.dueOn),
      returnedOn: returnedOn ?? this.returnedOn,
      requestNote: requestNote,
      responseNote: responseNote ?? this.responseNote,
    );
  }
}
