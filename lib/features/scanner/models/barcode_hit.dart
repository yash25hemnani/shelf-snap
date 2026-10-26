import 'package:shelf_snap/features/library/models/book_model.dart';

enum HitStatus { loading, found, notFound, failed }

class BarcodeHit {
  final String isbn;
  final HitStatus status;
  final BookModel? book;

  const BarcodeHit({
    required this.isbn,
    this.status = HitStatus.loading,
    this.book,
  });
}
