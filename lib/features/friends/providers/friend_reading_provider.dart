import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';

// Finished and DNF books loaded per page on a friend's page
const friendEndedPageSize = 20;

// A friend's reading and paused books, up to 10
final friendCurrentLogsProvider = StreamProvider.autoDispose
    .family<List<ReadingLogModel>, String>((ref, friendUid) {
      return ref
          .watch(readingLogRepositoryProvider)
          .watchFriendCurrentLogs(friendUid);
    });

// How many ended books the friend's page has asked for so far
final friendEndedLimitProvider = StateProvider.autoDispose
    .family<int, String>((ref, friendUid) => friendEndedPageSize);

// A friend's finished and DNF books, newest first, up to the current limit
final friendEndedLogsProvider = StreamProvider.autoDispose
    .family<List<ReadingLogModel>, String>((ref, friendUid) {
      final limit = ref.watch(friendEndedLimitProvider(friendUid));

      return ref
          .watch(readingLogRepositoryProvider)
          .watchFriendEndedLogs(friendUid, limit: limit);
    });

// Books the friend finished this year and their pages
final friendYearStatsProvider = FutureProvider.autoDispose
    .family<({int finished, int pagesRead}), String>((ref, friendUid) {
      return ref
          .watch(readingLogRepositoryProvider)
          .friendYearStats(friendUid, DateTime.now().year);
    });
