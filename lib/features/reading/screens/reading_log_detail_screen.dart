import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/section_card.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/widgets/status_dropdown.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
import 'package:shelf_snap/features/reading/widgets/edit_dates_sheet.dart';
import 'package:shelf_snap/features/reading/widgets/number_dialog.dart';

// One book on the reading list: status, progress and dates of the latest read
class ReadingLogDetailScreen extends ConsumerStatefulWidget {
  final String readingKey;
  const ReadingLogDetailScreen({super.key, required this.readingKey});

  @override
  ConsumerState<ReadingLogDetailScreen> createState() =>
      _ReadingLogDetailScreenState();
}

class _ReadingLogDetailScreenState
    extends ConsumerState<ReadingLogDetailScreen> {
  // The page under the slider while dragging; null shows the saved page
  int? _dragPage;

  Future<void> _onStatusChanged(ReadingLogModel log, BookStatus status) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null || status == log.status) return;

    // updateStatus takes a book; the log's copy gives the same readingKey
    final book = BookModel(
      id: log.bookId,
      title: log.title,
      authors: log.authors,
      coverUrl: log.coverUrl,
      pageCount: log.pageCount,
    );

    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref
          .read(readingLogRepositoryProvider)
          .updateStatus(status, book, userId);
      if (!saved) {
        messenger.showMessage("Can't move this book back to ${status.label}");
      }
    } catch (e) {
      debugPrint('updateStatus failed: $e');
      messenger.showError("Couldn't update status, check your connection");
    }
  }

  // Set or fix the book's page count; 0 from Google Books counts as missing
  Future<void> _editPageCount(ReadingLogModel log) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final current = log.pageCount;
    final value = await showNumberDialog(
      context,
      title: 'Page count',
      initial: current != null && current > 0 ? current : null,
    );
    if (value == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updatePageCount(value, widget.readingKey, userId);
    } catch (e) {
      debugPrint('updatePageCount failed: $e');
      messenger.showError("Couldn't save page count, check your connection");
    }
  }

  // Progress is always in pages, since the page count is required first
  Future<void> _saveProgress(int page) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateProgess(page, ProgressUnit.pages, widget.readingKey, userId);
    } catch (e) {
      debugPrint('updateProgess failed: $e');
      messenger.showError("Couldn't save progress, check your connection");
    } finally {
      // The saved value comes back through the stream
      if (mounted) setState(() => _dragPage = null);
    }
  }

  // Type an exact page, for when dragging is too rough
  Future<void> _editProgress(int currentPage, int pageCount) async {
    final value = await showNumberDialog(
      context,
      title: 'Current page',
      initial: currentPage,
      min: 0,
      max: pageCount,
    );
    if (value == null || !mounted) return;
    await _saveProgress(value);
  }

  Future<void> _editDates(ReadModel read) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final result = await showEditDatesSheet(context, read);
    if (result == null || !mounted) return; // cancelled

    final (start, end) = result;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateDates(start, end, widget.readingKey, userId);
    } catch (e) {
      debugPrint('updateDates failed: $e');
      messenger.showError("Couldn't save dates, check your connection");
    }
  }

  // A read from the history; it has no copy on the log
  Future<void> _editPastRead(ReadModel read) async {
    final userId = AuthService().currentUser?.uid;
    final readId = read.id;
    if (userId == null || readId == null) return;

    final result = await showEditDatesSheet(
      context,
      read,
      title: 'Edit previous read',
    );
    if (result == null || !mounted) return; // cancelled

    final (start, end) = result;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateReadDates(start, end, readId, widget.readingKey, userId);
    } catch (e) {
      debugPrint('updateReadDates failed: $e');
      messenger.showError("Couldn't save the read, check your connection");
    }
  }

  Future<void> _deletePastRead(ReadModel read) async {
    final userId = AuthService().currentUser?.uid;
    final readId = read.id;
    if (userId == null || readId == null) return;

    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete this read?',
      message: 'It will be removed from your history.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .deletePastRead(readId, widget.readingKey, userId);
      messenger.showMessage('Read deleted');
    } catch (e) {
      debugPrint('deletePastRead failed: $e');
      messenger.showError("Couldn't delete the read, check your connection");
    }
  }

  // A new read from page 0; the ended one stays as history
  Future<void> _startAgain() async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.replay_rounded,
      title: 'Start again?',
      message:
          'A new read starts from page 0. This one is kept in your history.',
      confirmLabel: 'Start again',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .startAgain(widget.readingKey, userId);
      messenger.showMessage('Started a new read');
    } catch (e) {
      debugPrint('startAgain failed: $e');
      messenger.showError("Couldn't start again, check your connection");
    }
  }

  // A finished read from before, added to the history
  Future<void> _addPreviousRead() async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    // An empty finished read, so the sheet asks for both dates
    final result = await showEditDatesSheet(
      context,
      ReadModel(userId: userId, status: BookStatus.finished),
      title: 'Add previous read',
    );
    if (result == null || !mounted) return; // cancelled

    final (start, end) = result;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .addPreviousRead(start, end!, widget.readingKey, userId);
      messenger.showMessage('Previous read added');
    } catch (e) {
      debugPrint('addPreviousRead failed: $e');
      messenger.showError("Couldn't add the read, check your connection");
    }
  }

  Future<void> _confirmDelete() async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove from reading list?',
      message: 'Its progress, dates and history will be deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .deleteLog(widget.readingKey, userId);
      navigator.pop();
      messenger.showMessage('Removed from reading list');
    } catch (e) {
      debugPrint('deleteLog failed: $e');
      messenger.showError("Couldn't delete, check your connection");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final logAsync = ref.watch(readingLogProvider(widget.readingKey));
    final reads = ref.watch(readsProvider(widget.readingKey)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading log'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
        // A thin line between the bar and the page
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: _addPreviousRead,
                child: const ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('Add previous read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                onTap: _confirmDelete,
                child: const ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: logAsync.when(
        data: (log) {
          // Deleted while open, or never saved
          if (log == null) {
            return Center(
              child: Text(
                'This book is not on your reading list',
                style: muted,
              ),
            );
          }

          final read = log.latestRead;
          // Google Books sends 0 when it doesn't know, so that counts as missing.
          // Progress, dates and history stay hidden until it's added.
          final hasPages = (log.pageCount ?? 0) > 0;
          final pageCount = log.pageCount ?? 0;

          // The page to show: finished is the last page; old percent
          // progress is turned into a page; the drag wins while moving
          var savedPage = 0;
          if (read != null && hasPages) {
            savedPage = read.status == BookStatus.finished
                ? pageCount
                : read.progressUnit == ProgressUnit.percent
                ? (read.progressValue * pageCount / 100).round()
                : read.progressValue;
          }
          final currentPage = (_dragPage ?? savedPage).clamp(0, pageCount);
          // The current read is shown above, so history is the rest
          final history = (reads ?? const <ReadModel>[])
              .where((r) => r.id != read?.id)
              .toList();
          final coverUrl = log.coverUrl;
          const placeholder = ColoredBox(
            color: AppColors.surfaceMuted,
            child: Center(
              child: Icon(Icons.book, size: 40, color: AppColors.hint),
            ),
          );

          final percent = hasPages
              ? (currentPage * 100 / pageCount).round()
              : 0;
          final small = textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 128,
                          height: 192,
                          child: coverUrl == null
                              ? placeholder
                              : Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => placeholder,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.title, style: textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              log.authors.isEmpty
                                  ? 'Unknown author'
                                  : log.authors.join(', '),
                              style: muted,
                            ),
                            if (hasPages) ...[
                              const SizedBox(height: 4),
                              // Tap the row to fix a wrong page count
                              InkWell(
                                onTap: () => _editPageCount(log),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.menu_book_outlined,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${log.pageCount} pages',
                                        style: muted,
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            StatusDropdown(
                              value: log.status,
                              onChanged: (status) =>
                                  _onStatusChanged(log, status),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!hasPages)
                        _MissingPagesCard(onAdd: () => _editPageCount(log)),

                      // Want to read has no read, so no progress or dates
                      if (hasPages && read != null) ...[
                        SectionCard(
                          icon: Icons.bar_chart_rounded,
                          title: 'Progress',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Only a reading or paused read takes progress
                              if (read.isActive)
                                TextButton(
                                  onPressed: () =>
                                      _editProgress(currentPage, pageCount),
                                  child: const Text('Update'),
                                ),
                              SoftPill(label: '$percent%'),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                read.status == BookStatus.finished
                                    ? 'Finished · $pageCount pages'
                                    : 'Page $currentPage of $pageCount',
                                style: muted,
                              ),
                              // Drag to move the page; saved when the finger
                              // lifts. Ended reads show it but can't be dragged.
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 6,
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: AppColors.border,
                                  thumbColor: AppColors.primary,
                                  disabledActiveTrackColor: AppColors.primary,
                                  disabledInactiveTrackColor: AppColors.border,
                                  disabledThumbColor: AppColors.primary,
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16,
                                  ),
                                ),
                                child: Slider(
                                  // No side padding, so the track lines up
                                  // with the text above it
                                  padding: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 6,
                                  ),
                                  value: currentPage.toDouble(),
                                  max: pageCount.toDouble(),
                                  onChanged: read.isActive
                                      ? (v) => setState(
                                          () => _dragPage = v.round(),
                                        )
                                      : null,
                                  onChangeEnd: read.isActive
                                      ? (v) => _saveProgress(v.round())
                                      : null,
                                ),
                              ),
                              Row(
                                children: [
                                  Text('0', style: small),
                                  const Spacer(),
                                  Text('$pageCount', style: small),
                                ],
                              ),
                              // Saved on the last page but not finished yet.
                              // Uses the saved page, so it waits for the drag
                              // to end.
                              if (read.isActive &&
                                  _dragPage == null &&
                                  savedPage >= pageCount) ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => _onStatusChanged(
                                    log,
                                    BookStatus.finished,
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text('Mark as finished'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SectionCard(
                          icon: Icons.calendar_month_outlined,
                          title: 'Dates',
                          trailing: TextButton.icon(
                            onPressed: () => _editDates(read),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: Text('Started')),
                                  Text(
                                    read.startedAt?.label ?? 'Not set',
                                    style: muted,
                                  ),
                                ],
                              ),
                              // Only an ended read has an end date
                              if (!read.isActive) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        read.status == BookStatus.dnf
                                            ? 'Stopped'
                                            : 'Finished',
                                      ),
                                    ),
                                    Text(
                                      read.endedAt?.label ?? 'Not set',
                                      style: muted,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // A new read; this one stays in the history
                        if (!read.isActive) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _startAgain,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Start again'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],

                      if (hasPages) ...[
                        const SizedBox(height: 16),
                        SectionCard(
                          icon: Icons.shelves,
                          title: 'History',
                          trailing: TextButton.icon(
                            onPressed: _addPreviousRead,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Add'),
                          ),
                          child: history.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    'No past reads',
                                    textAlign: TextAlign.center,
                                    style: muted,
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (final past in history) ...[
                                      _HistoryCard(
                                        read: past,
                                        onEdit: () => _editPastRead(past),
                                        onDelete: () => _deletePastRead(past),
                                      ),
                                      if (past != history.last)
                                        const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        error: (e, _) => Center(child: Text('Could not load this book: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// Shown instead of progress, dates and history until the page count is added
class _MissingPagesCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _MissingPagesCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('Page count missing', style: textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't find how many pages this book has. "
            'Add it to track your progress.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onAdd, child: const Text('Add page count')),
        ],
      ),
    );
  }
}

// One past read: how it ended and when. Tap to edit, or use the menu.
class _HistoryCard extends StatelessWidget {
  final ReadModel read;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.read,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final finished = read.status == BookStatus.finished;

    // Material + InkWell so the tap ripple stays inside the rounded border
    return Material(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          // Less on the right, since the menu button has its own padding
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: Row(
            children: [
              Icon(
                finished ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: finished ? AppColors.primary : AppColors.hint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(read.status.label, style: textTheme.titleSmall),
                    Text(
                      '${read.startedAt?.label ?? 'No start date'}'
                      ' – ${read.endedAt?.label ?? 'Now'}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<void>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.hint,
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onEdit,
                    child: const ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    onTap: onDelete,
                    child: const ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.error),
                      ),
                      contentPadding: EdgeInsets.zero,
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
