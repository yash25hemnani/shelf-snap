import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/profile/models/user_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

// Search people by username and invite them to a library
class InviteSheet extends ConsumerStatefulWidget {
  final LibraryModel library;
  const InviteSheet({super.key, required this.library});

  static Future<void> show(BuildContext context, LibraryModel library) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteSheet(library: library),
    );
  }

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  final Set<String> _sent = {}; // uids invited while the sheet is open
  String? _sendingUid; // uid with a request in flight

  // The sheet's own messenger, so SnackBars show on top of the sheet
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Runs on every keystroke in the search box
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _search(text));
  }

  Future<void> _search(String text) async {
    final users = await ref.read(userRepositoryProvider).searchUsers(text);

    if (!mounted || text != _searchController.text) return;

    // People already in the library can't be invited again
    setState(() {
      _results = users
          .where((u) => !widget.library.members.contains(u.uid))
          .toList();
    });
  }

  Future<void> _invite(UserModel to) async {
    final uid = AuthService().currentUser!.uid;

    // Your own profile, already loaded by AuthGate
    final me = ref.read(userProfileProvider(uid)).valueOrNull;
    final pending = ref
        .read(pendingInviteesProvider(widget.library.id!))
        .valueOrNull;
    if (me == null || _sendingUid != null) return;
    // Guards a tap that lands before the list above has loaded
    if (pending?.contains(to.uid) ?? false) return;

    setState(() => _sendingUid = to.uid);
    try {
      await ref
          .read(inviteRepositoryProvider)
          .sendInvite(library: widget.library, from: me, to: to);
      if (mounted) setState(() => _sent.add(to.uid));
    } catch (e) {
      _showError("Couldn't invite @${to.username}, check your connection");
    } finally {
      if (mounted) setState(() => _sendingUid = null);
    }
  }

  void _showError(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Invites from earlier visits, plus ones sent just now (shown straight
    // away, before Firestore reports them)
    final invited = {
      ...?ref.watch(pendingInviteesProvider(widget.library.id!)).valueOrNull,
      ..._sent,
    };

    // Fixed height so the results list can scroll inside the sheet
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: ScaffoldMessenger(
        key: _messengerKey,
        // Scaffold gives the messenger somewhere to show SnackBars
        // and shrinks its body above the keyboard
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          trailing: invited.contains(user.uid)
                              ? const Text('Sent')
                              : FilledButton.tonal(
                                  // Disabled while any invite is sending
                                  onPressed: _sendingUid == null
                                      ? () => _invite(user)
                                      : null,
                                  child: _sendingUid == user.uid
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Invite'),
                                ),
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
