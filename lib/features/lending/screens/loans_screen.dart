import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/book_detail_screen.dart';

// Books the user borrowed and books lent out from libraries they manage,
// switched with chips at the top
class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  LoanDirection _direction = LoanDirection.borrowed;

  // The book page needs the whole book, so it's read once before opening
  Future<void> _openBook(LoanModel loan) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final book = await ref
          .read(libraryRepositoryProvider)
          .watchBook(loan.libraryId, loan.bookId)
          .first;
      if (!mounted) return;

      if (book == null) {
        messenger.showMessage('This book is no longer in the library');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
      );
    } catch (e) {
      debugPrint('open loan book failed: $e');
      messenger.showError("Couldn't open the book, check your connection");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loansAsync = ref.watch(loansProvider(_direction));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final direction in LoanDirection.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        direction == LoanDirection.borrowed
                            ? 'Borrowed'
                            : 'Lent',
                      ),
                      selected: _direction == direction,
                      onSelected: (_) =>
                          setState(() => _direction = direction),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: loansAsync.when(
              data: (loans) {
                if (loans.isEmpty) {
                  return Center(
                    child: Text(
                      _direction == LoanDirection.borrowed
                          ? 'No borrowed books yet'
                          : 'Nothing lent out yet',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                // Open loans first; sort is stable, so each group stays
                // newest first
                final sorted = [...loans]
                  ..sort(
                    (a, b) => (b.isActive ? 1 : 0) - (a.isActive ? 1 : 0),
                  );

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _LoanTile(
                    loan: sorted[i],
                    direction: _direction,
                    onTap: () => _openBook(sorted[i]),
                  ),
                );
              },
              error: (e, _) => Center(child: Text('Could not load loans: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

// One loan: cover, title, who or where, the latest date and the status
class _LoanTile extends StatelessWidget {
  final LoanModel loan;
  final LoanDirection direction;
  final VoidCallback onTap;

  const _LoanTile({
    required this.loan,
    required this.direction,
    required this.onTap,
  });

  String get _dateLine {
    final due = loan.dueOn;
    return switch (loan.status) {
      LoanStatus.requested => [
        'Asked',
        if (loan.requestedOn case final asked?) dayMonth(asked),
        if (loan.collectOn case final collect?) '· collects ${dayMonth(collect)}',
      ].join(' '),
      LoanStatus.approved => [
        'Approved',
        if (loan.collectOn case final collect?) '· collects ${dayMonth(collect)}',
        if (due != null) '· return by ${dayMonth(due)}',
      ].join(' '),
      LoanStatus.lent => [
        if (loan.lentOn case final lent?) 'Since ${dayMonth(lent)}' else 'Out',
        if (due != null)
          loan.isOverdue
              ? '· overdue since ${dayMonth(due)}'
              : '· return by ${dayMonth(due)}',
      ].join(' '),
      // The status line already says what happened, so just the date
      LoanStatus.returned || LoanStatus.lost =>
        loan.returnedOn == null ? '' : 'On ${dayMonth(loan.returnedOn!)}',
      LoanStatus.rejected || LoanStatus.cancelled =>
        loan.respondedOn == null ? '' : 'On ${dayMonth(loan.respondedOn!)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final coverUrl = loan.coverUrl;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    final who = direction == LoanDirection.borrowed
        ? loan.libraryName
        : (loan.borrowerName.isEmpty ? 'Someone' : loan.borrowerName);

    final statusColor = loan.isOverdue
        ? AppColors.error
        : switch (loan.status) {
            LoanStatus.requested => AppColors.warning,
            LoanStatus.approved || LoanStatus.lent => AppColors.accent,
            LoanStatus.returned => AppColors.primary,
            LoanStatus.lost => AppColors.error,
            LoanStatus.rejected || LoanStatus.cancelled =>
              AppColors.textSecondary,
          };

    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, color: AppColors.hint)),
    );

    // Material + InkWell so the tap ripple stays inside the rounded border
    return Material(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: coverUrl == null
                      ? placeholder
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.bookTitle,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      who,
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loan.isOverdue ? 'Overdue' : loan.status.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: statusColor,
                      ),
                    ),
                    if (_dateLine case final line when line.isNotEmpty)
                      Text(
                        line,
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}
