import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/friends/models/friendship_model.dart';
import 'package:shelf_snap/features/friends/providers/friendship_provider.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

// Search people by @username and send them a friend request
class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddFriendSheet(),
    );
  }

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  String? _busyUid; // uid with a write in flight

  // The sheet's own messenger, so snackbars show on top of the sheet
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Waits for a pause in typing, so each keystroke isn't a query
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String text) async {
    try {
      final users = await ref
          .read(userRepositoryProvider)
          .searchUsers(text.trim().replaceFirst('@', ''));
      if (!mounted || text != _searchController.text) return;
      setState(() => _results = users);
    } catch (e) {
      debugPrint('searchUsers failed: $e');
      _messengerKey.currentState?.showError("Couldn't search right now");
    }
  }

  Future<void> _send(UserModel to) async {
    final uid = ref.read(currentUidProvider).valueOrNull;
    final me = uid == null
        ? null
        : ref.read(userProfileProvider(uid)).valueOrNull;
    if (me == null || _busyUid != null) return;

    setState(() => _busyUid = to.uid);
    try {
      await ref
          .read(friendshipRepositoryProvider)
          .sendRequest(from: me, to: to);
      _messengerKey.currentState?.showMessage(
        'Request sent to @${to.username}',
      );
    } catch (e) {
      debugPrint('sendRequest failed: $e');
      _messengerKey.currentState?.showError(
        "Couldn't send the request to @${to.username}",
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _accept(FriendshipModel request) async {
    if (_busyUid != null) return;
    setState(() => _busyUid = request.fromUid);
    try {
      await ref.read(friendshipRepositoryProvider).accept(request);
      _messengerKey.currentState?.showMessage(
        'You and @${request.fromUsername} are now friends',
      );
    } catch (e) {
      debugPrint('accept failed: $e');
      _messengerKey.currentState?.showError("Couldn't accept the request");
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  // What the row offers, from the friendship already loaded for Profile,
  // so the search costs no extra reads per result
  Widget _trailing(UserModel user, FriendshipModel? f, String myUid) {
    if (_busyUid == user.uid) {
      return const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (f == null) {
      return FilledButton.tonal(
        onPressed: _busyUid == null ? () => _send(user) : null,
        child: const Text('Add'),
      );
    }
    if (f.isIncoming(myUid)) {
      return FilledButton(
        onPressed: _busyUid == null ? () => _accept(f) : null,
        child: const Text('Accept'),
      );
    }

    return Text(
      f.isPending ? 'Sent' : 'Friends',
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(currentUidProvider).valueOrNull ?? '';
    final byUid = {
      for (final f in ref.watch(friendshipsProvider).valueOrNull ?? const [])
        f.otherUid(myUid): f,
    };

    // Fixed height so the results list can scroll inside the sheet
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: ScaffoldMessenger(
        key: _messengerKey,
        // Scaffold gives the messenger somewhere to show snackbars
        // and shrinks its body above the keyboard
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add a friend',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: _onChanged,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    hintText: 'Search by username',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final user in _results)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(user.name),
                          subtitle: Text('@${user.username}'),
                          trailing: _trailing(user, byUid[user.uid], myUid),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
