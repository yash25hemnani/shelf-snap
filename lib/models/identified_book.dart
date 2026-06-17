/// A book identified by the Gemini-backed identifyBooks Cloud Function
/// from a group of OCR text fragments. Gemini has already done the
/// fragment-grouping and garbled-text reconstruction that would otherwise
/// have to be attempted geometrically from raw bounding boxes.
class IdentifiedBook {
  final String title;
  final String author;

  const IdentifiedBook({required this.title, required this.author});

  /// Combined query string passed to [BookSearchService].
  String get searchQuery => author.isEmpty ? title : '$title $author';

  @override
  String toString() => 'IdentifiedBook(title: "$title", author: "$author")';
}