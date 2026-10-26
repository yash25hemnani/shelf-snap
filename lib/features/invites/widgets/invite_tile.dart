import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/invites/models/invite_model.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';

// One pending invite with Accept and Decline buttons
class InviteTile extends ConsumerStatefulWidget {
  final InviteModel invite;
  const InviteTile({super.key, required this.invite});

  @override
  ConsumerState<InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends ConsumerState<InviteTile> {
  bool _busy = false; // true while accept or decline is in flight

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);

    // Taken before the await: the row leaves the list as soon as the
    // invite changes locally, often before the write finishes
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(inviteRepositoryProvider).accept(widget.invite);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Joined ${widget.invite.libraryName}')),
        );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("Couldn't join, check your connection"),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(inviteRepositoryProvider).decline(widget.invite);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Invite declined')));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("Couldn't decline, check your connection"),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = widget.invite;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '@${invite.fromUsername}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: ' invited you to '),
                  TextSpan(
                    text: invite.libraryName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : _decline,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _accept,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
