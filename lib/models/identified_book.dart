/// A book identified by the Gemini-backed identifyBooks Cloud Function
/// from a group of OCR text fragments. Replaces DetectedSpine as the unit
/// passed into BookSearchService — Gemini has already done the
/// fragment-grouping and garbled-text reconstruction that
/// SpineDetectionService used to attempt geometrically.
class IdentifiedBook {
  final String title;
  final String author;

  const IdentifiedBook({required this.title, required this.author});

  /// Combined query string for BookSearchService — same shape as the
  /// fullText DetectedSpine used to provide.
  String get searchQuery => author.isEmpty ? title : '$title $author';

  @override
  String toString() => 'IdentifiedBook(title: "$title", author: "$author")';
}