import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/section_card.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/lending/repositories/loan_repository.dart';
import 'package:shelf_snap/features/lending/sheets/answer_loan_sheet.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

// The editor's side of lending on a book page: open requests and the
// copies that are out, each with its next step
class BookLoansCard extends ConsumerWidget {
  final String libraryId;
  final BookModel book;

  const BookLoansCard({super.key, required this.libraryId, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);

    final loans = ref
        .watch(bookLoansProvider((libraryId: libraryId, bookId: book.id!)))
        .valueOrNull;
    // Nothing until we know, so "No requests" doesn't flash first
    if (loans == null) return const SizedBox.shrink();

    final copies = book.noOfCopies;
    final available = book.availableCopies;

    return SectionCard(
      icon: Icons.handshake_outlined,
      title: 'Loans',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$available of $copies ${copies == 1 ? 'copy' : 'copies'} '
            'on the shelf',
            style: muted,
          ),
          if (loans.isEmpty) ...[
            const SizedBox(height: 4),
            Text('No requests yet', style: muted),
          ],
          for (final loan in loans) ...[
            const Divider(height: 24),
            _LoanRow(
              loan: loan,
              canHandOver: available > 0,
              lastCopy: copies <= 1,
            ),
          ],
        ],
      ),
    );
  }
}

// One borrower: what's happening, the main action, and a menu for the rest
class _LoanRow extends ConsumerWidget {
  final LoanModel loan;
  final bool canHandOver;
  final bool lastCopy; // losing it removes the book from the library

  const _LoanRow({
    required this.loan,
    required this.canHandOver,
    required this.lastCopy,
  });

  String get _name => loan.borrowerName.isEmpty ? 'Someone' : loan.borrowerName;

  // Runs one repository call with the snackbars around it; true when it
  // went through
  Future<bool> _run(
    BuildContext context,
    Future<void> Function(String loanId, String userId) action, {
    required String done,
    required String failed,
  }) async {
    final userId = AuthService().currentUser?.uid;
    final loanId = loan.id;
    if (userId == null || loanId == null) return false;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(loanId, userId);
      messenger.showMessage(done);
      return true;
    } catch (e) {
      debugPrint('loan action failed: $e');
      messenger.showError(loanErrorText(e, failed));
      return false;
    }
  }

  Future<void> _answer(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final status = await showAnswerLoanSheet(context, loan: loan);

    switch (status) {
      case LoanStatus.approved:
        messenger.showMessage('Approved. Hand it over when $_name collects it');
      case LoanStatus.rejected:
        messenger.showMessage('Request rejected');
      default:
        break;
    }
  }

  Future<void> _handOver(BuildContext context, WidgetRef ref) async {
    final due = loan.dueOn;
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.handshake_outlined,
      title: 'Hand over to $_name?',
      message: due == null
          ? 'One copy will be marked as lent, with no return date.'
          : 'One copy will be marked as lent until ${dayMonth(due)}.',
      confirmLabel: 'Hand over',
    );
    if (!confirmed || !context.mounted) return;

    await _run(
      context,
      ref.read(loanRepositoryProvider).markLent,
      done: 'Lent to $_name',
      failed: "Couldn't hand it over, check your connection",
    );
  }

  Future<void> _returned(BuildContext context, WidgetRef ref) => _run(
    context,
    ref.read(loanRepositoryProvider).markReturned,
    done: 'Back on the shelf',
    failed: "Couldn't mark it returned, check your connection",
  );

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.block_rounded,
      title: 'Reject the request?',
      message: "$_name won't be able to collect the book.",
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    await _run(
      context,
      (loanId, userId) =>
          ref.read(loanRepositoryProvider).rejectLoan(loanId, userId),
      done: 'Request rejected',
      failed: "Couldn't reject, check your connection",
    );
  }

  Future<void> _lost(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.report_outlined,
      title: 'Mark as lost?',
      message: lastCopy
          ? 'The loan ends and the book is removed from the library, '
                'since this is the only copy.'
          : 'The loan ends and the library has one copy fewer.',
      confirmLabel: 'Mark lost',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final done = await _run(
      context,
      ref.read(loanRepositoryProvider).markLost,
      done: lastCopy ? 'Marked as lost and removed' : 'Marked as lost',
      failed: "Couldn't update the loan, check your connection",
    );
    // The book is gone, so its page has nothing left to show
    if (done && lastCopy && context.mounted) Navigator.pop(context);
  }

  Future<void> _changeDue(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = loan.dueOn;

    final picked = await showDatePicker(
      context: context,
      // An overdue date is before today, so it can't be the starting date
      initialDate: current != null && !current.isBefore(today)
          ? current
          : today.add(const Duration(days: 14)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Return by',
    );
    if (picked == null || !context.mounted) return;

    await _run(
      context,
      (loanId, userId) => ref
          .read(loanRepositoryProvider)
          .updateDueDate(loanId, userId, picked),
      done: 'Return date set to ${dayMonth(picked)}',
      failed: "Couldn't change the date, check your connection",
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );

    final collect = loan.collectOn;
    final due = loan.dueOn;
    final lines = switch (loan.status) {
      LoanStatus.requested => [
        [
          'Asked',
          if (loan.requestedOn case final asked?) dayMonth(asked),
          if (collect != null) '· collects ${dayMonth(collect)}',
          if (due != null) '· until ${dayMonth(due)}',
        ].join(' '),
        if (loan.requestNote case final note?) '“$note”',
      ],
      LoanStatus.approved => [
        [
          'Approved',
          if (collect != null) '· collects ${dayMonth(collect)}',
          if (due != null) '· return by ${dayMonth(due)}',
        ].join(' '),
      ],
      _ => [
        [
          'Has it',
          if (loan.lentOn case final lent?) 'since ${dayMonth(lent)}',
          if (due != null)
            loan.isOverdue
                ? '· overdue since ${dayMonth(due)}'
                : '· return by ${dayMonth(due)}',
        ].join(' '),
      ],
    };

    final action = switch (loan.status) {
      LoanStatus.requested => FilledButton(
        onPressed: () => _answer(context),
        child: const Text('Answer'),
      ),
      LoanStatus.approved => FilledButton(
        onPressed: canHandOver ? () => _handOver(context, ref) : null,
        child: Text(canHandOver ? 'Hand over' : 'No copy free'),
      ),
      _ => OutlinedButton(
        onPressed: () => _returned(context, ref),
        child: const Text('Returned'),
      ),
    };

    final menu = switch (loan.status) {
      LoanStatus.approved => [
        PopupMenuItem(
          onTap: () => _changeDue(context, ref),
          child: const Text('Change return date'),
        ),
        PopupMenuItem(
          onTap: () => _reject(context, ref),
          child: const Text('Reject', style: TextStyle(color: AppColors.error)),
        ),
      ],
      LoanStatus.lent => [
        PopupMenuItem(
          onTap: () => _changeDue(context, ref),
          child: const Text('Change return date'),
        ),
        PopupMenuItem(
          onTap: () => _lost(context, ref),
          child: const Text(
            'Mark as lost',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
      _ => const <PopupMenuItem<void>>[],
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name, style: textTheme.titleSmall),
              for (final (i, line) in lines.indexed)
                Text(
                  line,
                  style: i == 0 && loan.isOverdue
                      ? textTheme.bodyMedium?.copyWith(color: AppColors.error)
                      : muted,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
        if (menu.isNotEmpty)
          PopupMenuButton<void>(itemBuilder: (_) => menu)
        else
          // Keeps the buttons lined up with the rows that have a menu
          const SizedBox(width: 48),
      ],
    );
  }
}
