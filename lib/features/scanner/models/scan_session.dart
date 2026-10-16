import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';

class ScanSession {
  final int pending;
  final List<ScoredBookResult> results;

  const ScanSession({this.pending = 0, this.results = const []});

  bool get busy => pending > 0;

  ScanSession copyWith({int? pending, List<ScoredBookResult>? results}) =>
      ScanSession(
        pending: pending ?? this.pending,
        results: results ?? this.results,
      );
}
