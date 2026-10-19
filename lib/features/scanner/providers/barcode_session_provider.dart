import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/models/book_model.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';

class BarcodeSessionNotifier
    extends AutoDisposeNotifier<Map<String, BarcodeHit>> {
  @override
  Map<String, BarcodeHit> build() => const {};

  // Returns false if the ISBN is already in the session
  bool add(String isbn) {
    if (state.containsKey(isbn)) return false;

    state = {...state, isbn: BarcodeHit(isbn: isbn)};
    return true;
  }

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