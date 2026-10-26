import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/scanner/models/scan_session.dart';
import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';
import 'package:shelf_snap/features/scanner/services/shelf_capture_service.dart';

class ScanSessionNotifier extends AutoDisposeNotifier<ScanSession> {
  @override
  ScanSession build() => const ScanSession(); // initial state

  // Captures in flight at once; each one is a Groq call with an image
  static const maxPending = 2;

  void startProcessing() => state = state.copyWith(pending: state.pending + 1);

  void addResults(List<ScoredBookResult> results) {
    // Existing results by key; a Map keeps insertion order
    final byKey = {for (final r in state.results) _keyFor(r): r};

    for (final r in results) {
      final key = _keyFor(r);
      final existing = byKey[key];
      // Same book from another photo: keep whichever match scored higher
      if (existing == null || r.score > existing.score) {
        byKey[key] = r;
      }
    }

    state = state.copyWith(
      pending: state.pending - 1,
      results: byKey.values.toList(),
    );
  }

  // Title + first author, so different editions of one book still merge
  static String _keyFor(ScoredBookResult r) =>
      r.book.readingKey ?? BookModel.normalize(r.book.title);

  void failProcessing() => state = state.copyWith(pending: state.pending - 1);

  void removeAt(int index) =>
      state = state.copyWith(results: [...state.results]..removeAt(index));

  void removeAll(List<ScoredBookResult> saved) => state = state.copyWith(
    results: state.results.where((r) => !saved.contains(r)).toList(),
  );

  void reset() => state = const ScanSession();
}

final scanSessionProvider =
    NotifierProvider.autoDispose<ScanSessionNotifier, ScanSession>(
      ScanSessionNotifier.new,
    );

final shelfCaptureServiceProvider = Provider.autoDispose((ref) {
  final service = ShelfCaptureService();
  ref.onDispose(service.close);
  return service;
});
