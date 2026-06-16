/// A book found via a metadata lookup (Open Library / Google Books),
/// matched against OCR'd spine text.

class BookResult {
  final String title;
  final String? author;
  final String? isbn;
  final String? coverUrl;
  final List<String> genres; // <- new

  BookResult({
    required this.title,
    this.author,
    this.isbn,
    this.coverUrl,
    this.genres = const [], // defaults to empty list if Google Books has none
  });

  @override
  String toString() =>
      'BookResult(title: "$title", author: $author, isbn: $isbn, genres: $genres)';
}