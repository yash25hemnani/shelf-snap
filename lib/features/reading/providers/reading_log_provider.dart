import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/repositories/reading_log_repository.dart';

final readingLogRepositoryProvider = Provider((ref) => ReadingLogRepository());

// The current user's log for one book; null when there's no log yet
final readingLogProvider = StreamProvider.family<ReadingLogModel?, String>((
  ref,
  readingKey,
) {
  final userId = AuthService().currentUser!.uid;
  return ref.watch(readingLogRepositoryProvider).watchLog(userId, readingKey);
});
