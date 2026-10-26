import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/repositories/user_repository.dart';

final userRepositoryProvider = Provider((ref) => UserRepository());

final userProfileProvider = StreamProvider.family<UserModel?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchUser(uid),
);
