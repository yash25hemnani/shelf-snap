import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/invites/widgets/invite_tile.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/widgets/join_request_tile.dart';

// Pending invites for the signed-in user, then requests to join the
// libraries they own
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = AuthService().currentUser!.uid;
    final invitesAsync = ref.watch(incomingInvitesProvider(uid));
    final requestsAsync = ref.watch(ownerJoinRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: invitesAsync.when(
        data: (invites) {
          // A failed requests query shouldn't hide the invites
          final requests = requestsAsync.valueOrNull ?? const [];
          if (invites.isEmpty && requests.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          // Answered invites and requests leave their streams, so their
          // rows disappear
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final invite in invites) ...[
                InviteTile(key: ValueKey(invite.id), invite: invite),
                const SizedBox(height: 12),
              ],
              for (final request in requests) ...[
                JoinRequestTile(
                  key: ValueKey('${request.libraryId}_${request.uid}'),
                  request: request,
                  showLibrary: true,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
