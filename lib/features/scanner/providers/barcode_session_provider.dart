import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';

class BarcodeSessionNotifier
    extends AutoDisposeNotifier<Map<String, BarcodeHit>> {
  @override
  Map<String, BarcodeHit> build() => const {};

  // Returns false if the ISBN is already in the session. A failed lookup
  // can be added again, which retries it.
  bool add(String isbn) {
    final existing = state[isbn];
    if (existing != null && existing.status != HitStatus.failed) return false;

    // Removed first so a retry moves to the end, as the newest scan
    state = {...state}
      ..remove(isbn)
      ..[isbn] = BarcodeHit(isbn: isbn);
    return true;
  }

  void fail(String isbn) => state = {
    ...state,
    isbn: BarcodeHit(isbn: isbn, status: HitStatus.failed),
  };

  void resolve(String isbn, BookModel? book) => state = {
    ...state,
    isbn: BarcodeHit(
      isbn: isbn,
      status: book == null ? HitStatus.notFound : HitStatus.found,
      book: book,
    ),
  };

  void remove(String isbn) => state = {...state}..remove(isbn);

  void reset() => state = const {};
}

final barcodeSessionProvider =
    NotifierProvider.autoDispose<BarcodeSessionNotifier, Map<String, BarcodeHit>>(
  BarcodeSessionNotifier.new,
);