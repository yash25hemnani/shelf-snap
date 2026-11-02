import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/repositories/user_repository.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

final userProfileProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  // Rebuilds on every sign in and sign out, so a permission-denied
  // from the last session isn't kept after signing back in
  final currentUid = ref.watch(currentUidProvider).valueOrNull;

  // Stays loading until this uid is the one signed in
  if (currentUid != uid) return const Stream.empty();

  return ref.watch(userRepositoryProvider).watchUser(uid);
});
