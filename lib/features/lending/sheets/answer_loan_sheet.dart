import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/lending/models/loan_model.dart';
import 'package:shelf_snap/features/lending/providers/loan_provider.dart';
import 'package:shelf_snap/features/lending/repositories/loan_repository.dart';
import 'package:shelf_snap/features/lending/widgets/loan_date_row.dart';

// An editor approves or rejects a request. Resolves to the new status,
// or null when closed without answering.
Future<LoanStatus?> showAnswerLoanSheet(
  BuildContext context, {
  required LoanModel loan,
}) {
  return showModalBottomSheet<LoanStatus>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AnswerLoanSheet(loan: loan),
  );
}

class _AnswerLoanSheet extends ConsumerStatefulWidget {
  final LoanModel loan;

  const _AnswerLoanSheet({required this.loan});

  @override
  ConsumerState<_AnswerLoanSheet> createState() => _AnswerLoanSheetState();
}

class _AnswerLoanSheetState extends ConsumerState<_AnswerLoanSheet> {
  final _note = TextEditingController();
  // The borrower's date, or two weeks after they collect it
  late DateTime? _dueOn = widget.loan.dueOn ?? _start.add(_twoWeeks);
  bool _sending = false;

  static const _twoWeeks = Duration(days: 14);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // The day the borrower takes the book: their collect date, or today
  DateTime get _start {
    final collect = widget.loan.collectOn;
    return collect != null && collect.isAfter(_today) ? collect : _today;
  }

  Future<void> _pickDue() async {
    final first = _start.add(const Duration(days: 1));
    final current = _dueOn;

    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first)
          ? current
          : first.add(const Duration(days: 13)),
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
      helpText: 'Return by',
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _answer(LoanStatus status) async {
    final userId = AuthService().currentUser?.uid;
    final loanId = widget.loan.id;
    if (userId == null || loanId == null || _sending) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(loanRepositoryProvider);

    try {
      if (status == LoanStatus.approved) {
        await repository.approveLoan(
          loanId,
          userId,
          dueOn: _dueOn,
          responseNote: _note.text,
        );
      } else {
        await repository.rejectLoan(loanId, userId, responseNote: _note.text);
      }

      if (!mounted) return;
      Navigator.pop(context, status);
    } catch (e) {
      debugPrint('answer loan failed: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showError(
        loanErrorText(e, "Couldn't answer, check your connection"),
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
    final loan = widget.loan;
    final name = loan.borrowerName.isEmpty ? 'Someone' : loan.borrowerName;

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
              Text('Answer request', style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('$name wants ${loan.bookTitle}', style: muted),
              if (loan.collectOn case final collect?) ...[
                const SizedBox(height: 4),
                Text('Collects on ${dayMonth(collect)}', style: muted),
              ],
              if (loan.requestNote case final note?) ...[
                const SizedBox(height: 4),
                Text('“$note”', style: muted),
              ],
              const SizedBox(height: 12),
              LoanDateRow(
                icon: Icons.event_repeat_outlined,
                label: 'Return by',
                date: _dueOn,
                onTap: _pickDue,
                onClear: () => setState(() => _dueOn = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Add a note for $name (optional)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending
                          ? null
                          : () => _answer(LoanStatus.rejected),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _sending
                          ? null
                          : () => _answer(LoanStatus.approved),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(_sending ? 'Sending...' : 'Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
