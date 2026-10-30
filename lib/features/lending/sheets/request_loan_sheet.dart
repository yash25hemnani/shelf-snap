import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/lending/repositories/loan_repository.dart';
import 'package:shelf_snap/features/lending/widgets/loan_date_row.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

// Asks to borrow a library book. Resolves to true once the request is sent.
Future<bool?> showRequestLoanSheet(
  BuildContext context, {
  required BookModel book,
  required LibraryModel library,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _RequestLoanSheet(book: book, library: library),
  );
}

class _RequestLoanSheet extends ConsumerStatefulWidget {
  final BookModel book;
  final LibraryModel library;

  const _RequestLoanSheet({required this.book, required this.library});

  @override
  ConsumerState<_RequestLoanSheet> createState() => _RequestLoanSheetState();
}

class _RequestLoanSheetState extends ConsumerState<_RequestLoanSheet> {
  final _note = TextEditingController();
  DateTime? _collectOn;
  DateTime? _dueOn;
  bool _sending = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickCollect() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _collectOn ?? _today,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
      helpText: 'Collect on',
    );
    if (picked == null) return;

    setState(() {
      _collectOn = picked;
      // A return date on or before the new collect date no longer fits
      final due = _dueOn;
      if (due != null && !due.isAfter(picked)) _dueOn = null;
    });
  }

  Future<void> _pickDue() async {
    final collect = _collectOn;
    final first = collect == null
        ? _today
        : collect.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn ?? first.add(const Duration(days: 13)),
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      helpText: 'Return by',
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _send() async {
    final userId = AuthService().currentUser?.uid;
    final libraryId = widget.library.id;
    final bookId = widget.book.id;
    if (userId == null || libraryId == null || bookId == null || _sending) {
      return;
    }

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final profile = await ref.read(userProfileProvider(userId).future);

      await ref
          .read(loanRepositoryProvider)
          .requestLoan(
            LoanModel(
              libraryId: libraryId,
              bookId: bookId,
              ownerId: widget.library.ownerId,
              borrowerId: userId,
              bookTitle: widget.book.title,
              coverUrl: widget.book.coverUrl,
              borrowerName: profile?.name ?? '',
              libraryName: widget.library.name,
              collectOn: _collectOn,
              dueOn: _dueOn,
              requestNote: _note.text,
            ),
            userId,
          );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('requestLoan failed: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showError(
        loanErrorText(e, "Couldn't send the request, check your connection"),
      );
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );

    return Padding(
      // Lifts the sheet above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ask to borrow', style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.book.title} from ${widget.library.name}',
                style: muted,
              ),
              const SizedBox(height: 12),
              LoanDateRow(
                icon: Icons.event_available_outlined,
                label: 'Collect on',
                date: _collectOn,
                onTap: _pickCollect,
                onClear: () => setState(() => _collectOn = null),
              ),
              LoanDateRow(
                icon: Icons.event_repeat_outlined,
                label: 'Return by',
                date: _dueOn,
                onTap: _pickDue,
                onClear: () => setState(() => _dueOn = null),
              ),
              const SizedBox(height: 4),
              Text(
                'Both are optional. The owner can change the return date.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add a note (optional)',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'Sending...' : 'Send request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
