import 'package:shelf_snap/core/models/book_result.dart';

/// A [BookResult] paired with the backend's similarity score between the
/// book read off the spine and its Google Books listing.
class ScoredBookResult {
  /// Minimum score to consider a result a "confident" match.
  static const double _confidentMatchThreshold = 0.4;

  final BookResult book;

  /// Similarity score 0.0–1.0. Higher = better match.
  final double score;

  /// Whether this is a confident match based on the score threshold.
  bool get isConfident => score >= _confidentMatchThreshold;

  ScoredBookResult({required this.book, required this.score});

  @override
  String toString() =>
      'ScoredBookResult("${book.title}", score: ${score.toStringAsFixed(2)})';
}
