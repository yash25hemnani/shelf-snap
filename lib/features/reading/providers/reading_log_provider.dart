import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/repositories/reading_log_repository.dart';

final readingLogRepositoryProvider = Provider((ref) => ReadingLogRepository());

// The current user's log for one book; null when there's no log yet
final readingLogProvider = StreamProvider.autoDispose
    .family<ReadingLogModel?, String>((ref, readingKey) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(null);

      return ref
          .watch(readingLogRepositoryProvider)
          .watchLog(userId, readingKey);
    });

// Every read of one book, latest end date first; empty when signed out
final readsProvider = StreamProvider.autoDispose
    .family<List<ReadModel>, String>((ref, readingKey) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);

      return ref
          .watch(readingLogRepositoryProvider)
          .watchReads(userId, readingKey);
    });

// The signed-in user's logs for one status; null means all
final readingLogsProvider = StreamProvider.autoDispose
    .family<List<ReadingLogModel>, BookStatus?>((ref, status) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);

      return ref
          .watch(readingLogRepositoryProvider)
          .watchLogs(userId, status: status);
    });

// Text typed in the My reading search bar
final readingSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

// Logs matching every word, within the selected chip; empty when the box is empty
final readingSearchProvider = StreamProvider.autoDispose
    .family<List<ReadingLogModel>, BookStatus?>((ref, status) {
      final words = BookModel.sanitizeWords(
        ref.watch(readingSearchQueryProvider),
      );
      if (words.isEmpty) return Stream.value(const []);

      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);

      // Longest word narrows the most
      words.sort((a, b) => b.length.compareTo(a.length));

      return ref
          .watch(readingLogRepositoryProvider)
          .searchLogs(userId, words.first, status: status)
          .map(
            (logs) => logs.where((log) {
              final tokens = log.searchTokens.toSet();
              return words.every(tokens.contains);
            }).toList(),
          );
    });

// Selected filter chip; null = All
final readingFilterProvider = StateProvider.autoDispose<BookStatus?>(
  (ref) => null,
);
