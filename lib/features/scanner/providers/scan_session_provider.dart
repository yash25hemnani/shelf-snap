import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/scanner/models/scan_session.dart';
import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';
import 'package:shelf_snap/features/scanner/services/shelf_capture_service.dart';

class ScanSessionNotifier extends AutoDisposeNotifier<ScanSession> {
  @override
  ScanSession build() => const ScanSession(); // initial state

  static const maxPending = 3;

  void startProcessing() => state = state.copyWith(pending: state.pending + 1);

  void addResults(List<ScoredBookResult> results) => state = state.copyWith(
    pending: state.pending - 1,
    results: [...state.results, ...results],
  );

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
