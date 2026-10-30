import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/invites/models/invite_model.dart';
import 'package:shelf_snap/features/invites/repositories/invite_repository.dart';

final inviteRepositoryProvider = Provider((ref) => InviteRepository());

final incomingInvitesProvider =
    StreamProvider.family<List<InviteModel>, String>(
      (ref, uid) => ref.watch(inviteRepositoryProvider).watchIncoming(uid),
    );

// Uids already invited to a library by the signed-in user and not yet
// answered, so the invite sheet doesn't offer them again
final pendingInviteesProvider = StreamProvider.autoDispose
    .family<Set<String>, String>((ref, libraryId) {
      final uid = ref.watch(currentUidProvider).valueOrNull;
      if (uid == null) return Stream.value(const {});

      return ref
          .watch(inviteRepositoryProvider)
          .watchPendingInvitees(libraryId, uid);
    });
