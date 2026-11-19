import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/join_request.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

// One request to join a library, with Decline and Approve for the owner.
// Notifications show which library it's for; the Members tab doesn't need to.
class JoinRequestTile extends ConsumerStatefulWidget {
  final JoinRequest request;
  final bool showLibrary;

  const JoinRequestTile({
    super.key,
    required this.request,
    this.showLibrary = false,
  });

  @override
  ConsumerState<JoinRequestTile> createState() => _JoinRequestTileState();
}

class _JoinRequestTileState extends ConsumerState<JoinRequestTile> {
  bool _busy = false; // true while approve or decline is in flight

  Future<void> _answer(bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);

    // The row leaves the list as soon as the request is deleted locally,
    // often before the write finishes
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(libraryRepositoryProvider);
    final request = widget.request;

    try {
      if (approve) {
        await repository.approveJoinRequest(request.libraryId, request.uid);
        messenger.showMessage(
          '@${request.username} joined ${request.libraryName}',
        );
      } else {
        await repository.deleteJoinRequest(request.libraryId, request.uid);
        messenger.showMessage('Request declined');
      }
    } catch (e) {
      debugPrint('${approve ? 'Approve' : 'Decline'} join request failed: $e');
      if (mounted) setState(() => _busy = false);
      messenger.showError(
        approve ? "Couldn't approve request" : "Couldn't decline request",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final request = widget.request;
    final bold = const TextStyle(fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '@${request.username}', style: bold),
                if (widget.showLibrary) ...[
                  const TextSpan(text: ' wants to join '),
                  TextSpan(text: request.libraryName, style: bold),
                ] else
                  const TextSpan(text: ' wants to join'),
              ],
            ),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _answer(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : () => _answer(true),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
