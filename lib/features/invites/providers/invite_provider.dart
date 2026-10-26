import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/invites/models/invite_model.dart';
import 'package:shelf_snap/features/invites/repositories/invite_repository.dart';

final inviteRepositoryProvider = Provider((ref) => InviteRepository());

final incomingInvitesProvider =
    StreamProvider.family<List<InviteModel>, String>(
      (ref, uid) => ref.watch(inviteRepositoryProvider).watchIncoming(uid),
    );
