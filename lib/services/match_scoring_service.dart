import 'package:string_similarity/string_similarity.dart';
import '../models/book_result.dart';

class MatchScoringService {
  /// Minimum similarity score to consider a result a "confident" match.
  /// Below this, we flag the result as a weak/uncertain match.
  static const double _confidentMatchThreshold = 0.4;

  /// Scores and sorts [candidates] by how closely they match [ocrText].
  /// Returns the same list, sorted best-match-first, with scores attached.
  List<ScoredBookResult> scoreAndRank(String ocrText, List<BookResult> candidates) {
    final normalizedOcr = _normalize(ocrText);

    final scored = candidates.map((candidate) {
      final candidateText = _normalize('${candidate.title} ${candidate.author ?? ''}');
      final score = StringSimilarity.compareTwoStrings(normalizedOcr, candidateText);
      return ScoredBookResult(book: candidate, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Deduplicate by title + author — keep highest scoring edition
    final seen = <String>{};
    final deduplicated = scored.where((result) {
      final key = '${result.book.title}_${result.book.author}'.toLowerCase();
      return seen.add(key); // add() returns false if already present
    }).toList();

    return deduplicated;
  }

  /// Whether the top match is confident enough to show as the primary result,
  /// or whether we should immediately prompt the user to pick from alternatives.
  bool isConfidentMatch(ScoredBookResult result) {
    return result.score >= _confidentMatchThreshold;
  }

  /// Normalizes text before comparison:
  /// lowercase, trim whitespace, remove punctuation.
  /// This prevents "The Elephant Vanishes" vs "THE ELEPHANT VANISHES"
  /// from scoring lower than they should.
  String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), ''); // remove punctuation
  }
}

/// A [BookResult] paired with its similarity score against the OCR input.
class ScoredBookResult {
  final BookResult book;

  /// Similarity score 0.0–1.0. Higher = better match.
  final double score;

  /// Whether this is a confident match based on the score threshold.
  bool get isConfident => score >= MatchScoringService._confidentMatchThreshold;

  ScoredBookResult({required this.book, required this.score});

  @override
  String toString() => 'ScoredBookResult("${book.title}", score: ${score.toStringAsFixed(2)})';
}