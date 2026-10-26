import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/invites/widgets/invite_tile.dart';

// Pending invites for the signed-in user
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = AuthService().currentUser!.uid;
    final invitesAsync = ref.watch(incomingInvitesProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: invitesAsync.when(
        data: (invites) {
          if (invites.isEmpty) {
            return const Center(child: Text('No invites'));
          }

          // Answered invites leave the stream, so their rows disappear
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invite = invites[index];
              return InviteTile(key: ValueKey(invite.id), invite: invite);
            },
          );
        },
        error: (err, _) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
