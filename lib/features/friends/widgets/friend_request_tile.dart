import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';
import 'package:shelf_snap/features/friends/widgets/person_tile.dart';

// A pending request: Accept and Decline when it was sent to me,
// Cancel when I sent it
class FriendRequestTile extends ConsumerStatefulWidget {
  final FriendshipModel request;
  final String myUid;

  const FriendRequestTile({
    super.key,
    required this.request,
    required this.myUid,
  });

  @override
  ConsumerState<FriendRequestTile> createState() => _FriendRequestTileState();
}

class _FriendRequestTileState extends ConsumerState<FriendRequestTile> {
  bool _busy = false; // true while a write is in flight

  String get _username => widget.request.otherUsername(widget.myUid);

  // Taken before the await: the row leaves the list as soon as the doc
  // changes locally, often before the write finishes
  Future<void> _run(
    String action,
    Future<void> Function() write,
    String done,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await write();
      messenger.showMessage(done);
    } catch (e) {
      debugPrint('$action failed: $e');
      if (mounted) setState(() => _busy = false);
      messenger.showError("Couldn't $action, check your connection");
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(friendshipRepositoryProvider);
    final request = widget.request;
    final incoming = request.isIncoming(widget.myUid);

    final Widget trailing;
    if (_busy) {
      trailing = const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (incoming) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () =>
                _run('decline', () => repo.remove(request), 'Request declined'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Decline'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: () => _run(
              'accept',
              () => repo.accept(request),
              'You and @$_username are now friends',
            ),
            child: const Text('Accept'),
          ),
        ],
      );
    } else {
      trailing = TextButton(
        onPressed: () =>
            _run('cancel', () => repo.remove(request), 'Request cancelled'),
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        child: const Text('Cancel'),
      );
    }

    return PersonTile(
      uid: request.otherUid(widget.myUid),
      username: _username,
      trailing: trailing,
    );
  }
}
