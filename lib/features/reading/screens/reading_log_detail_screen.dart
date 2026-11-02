import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/section_card.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/widgets/status_dropdown.dart';
import 'package:shelf_snap/features/reading/models/read_date.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
import 'package:shelf_snap/features/reading/widgets/edit_dates_sheet.dart';
import 'package:shelf_snap/features/reading/widgets/number_dialog.dart';
import 'package:shelf_snap/features/reading/widgets/review_sheet.dart';

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

  // One line under the slider instead of a separate Dates card
  String _datesLabel(ReadModel read) {
    final started = 'Started ${read.startedAt?.label ?? 'not set'}';
    if (read.isActive) return started;
    final ended = read.status == BookStatus.dnf ? 'stopped' : 'finished';
    return '$started, $ended ${read.endedAt?.label ?? 'not set'}';
  }

  // Days so far, pages a day and an estimated finish date. Needs a full
  // start date, since a month or a year alone can't give a day count.
  ({int days, int perDay, DateTime? finishBy})? _pace(
    ReadModel read,
    int page,
    int pageCount,
  ) {
    final start = read.startedAt;
    if (start == null || start.precision != DatePrecision.day) return null;

    // UTC dates, so a clock change can't cut a day short
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final startDay = DateTime.utc(start.year, start.month!, start.day!);
    // The start day counts as day one
    final days = today.difference(startDay).inDays + 1;
    if (days < 1) return null;

    final rate = page / days;
    final finishBy = rate > 0
        ? DateTime(
            now.year,
            now.month,
            now.day + ((pageCount - page) / rate).ceil(),
          )
        : null;
    return (days: days, perDay: rate.round(), finishBy: finishBy);
  }

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

  // Null clears it; tapping the current rating again does that
  Future<void> _saveRating(int? rating) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateRating(rating, widget.readingKey, userId);
    } catch (e) {
      debugPrint('updateRating failed: $e');
      messenger.showError("Couldn't save rating, check your connection");
    }
  }

  // Clearing the text removes the review
  Future<void> _editReview(String? current) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final text = await showReviewSheet(context, current: current);
    if (text == null || text == (current ?? '') || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateReview(text, widget.readingKey, userId);
    } catch (e) {
      debugPrint('updateReview failed: $e');
      messenger.showError("Couldn't save review, check your connection");
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
    // valueOrNull so the page doesn't wait on it; the cards fill in after
    final bookRating = ref
        .watch(bookRatingProvider(widget.readingKey))
        .valueOrNull;
    final loadedLog = logAsync.valueOrNull;

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
              // Rarely needed, so it lives here rather than on the page;
              // a missing count has its own card with a button
              if ((loadedLog?.pageCount ?? 0) > 0)
                PopupMenuItem(
                  onTap: () => _editPageCount(loadedLog!),
                  child: const ListTile(
                    leading: Icon(Icons.menu_book_outlined),
                    title: Text('Edit page count'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
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
          // Rating opens once the book has been finished or dropped at
          // least once, and stays open after that
          final canRate =
              bookRating?.rating != null ||
              bookRating?.review != null ||
              (read != null && !read.isActive) ||
              history.isNotEmpty;
          final rating = bookRating?.rating;
          final review = bookRating?.review;
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
          final pace = read != null && hasPages
              ? _pace(read, currentPage, pageCount)
              : null;

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
                            // A small link, so fixing a wrong count is easy
                            // to find but doesn't compete with the status
                            if (hasPages) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${log.pageCount} pages', style: muted),
                                  const SizedBox(width: 8),
                                  _InlineLink(
                                    label: 'Edit',
                                    onTap: () => _editPageCount(log),
                                  ),
                                ],
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
                        _ProgressCard(
                          currentPage: currentPage,
                          pageCount: pageCount,
                          percent: percent,
                          active: read.isActive,
                          pace: read.isActive ? pace : null,
                          onEditPage: () =>
                              _editProgress(currentPage, pageCount),
                          onDrag: (page) => setState(() => _dragPage = page),
                          onDragEnd: _saveProgress,
                          // Saved on the last page but not finished yet. Uses
                          // the saved page, so it waits for the drag to end.
                          onFinish:
                              read.isActive &&
                                  _dragPage == null &&
                                  savedPage >= pageCount
                              ? () => _onStatusChanged(log, BookStatus.finished)
                              : null,
                        ),
                        // A new read; this one stays in the history
                        if (!read.isActive) ...[
                          const SizedBox(height: 12),
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

                      // The smaller things in one list, so they read as part
                      // of the page instead of loose lines of text
                      if (hasPages) ...[
                        const SizedBox(height: 16),
                        _DetailsList(
                          rows: [
                            if (read != null)
                              _DetailRow(
                                icon: Icons.calendar_today_outlined,
                                title: _datesLabel(read),
                                action: 'Edit',
                                onTap: () => _editDates(read),
                              ),
                            // Says rating exists before it unlocks
                            if (!canRate && read != null)
                              const _DetailRow(
                                icon: Icons.star_outline_rounded,
                                title: 'Rating and review',
                                subtitle: 'Opens when you finish',
                              ),
                            if (history.isEmpty)
                              _DetailRow(
                                icon: Icons.history_rounded,
                                title: 'Read this before?',
                                action: 'Add',
                                onTap: _addPreviousRead,
                              ),
                          ],
                        ),
                      ],

                      if (canRate) ...[
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'Rating',
                          trailing: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SoftPill(
                              label: rating == null ? '–/10' : '$rating/10',
                            ),
                          ),
                          child: _RatingRow(
                            rating: rating,
                            onChanged: _saveRating,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SectionCard(
                          title: 'Review',
                          // Text-only, like every card action on this page
                          trailing: TextButton(
                            onPressed: () => _editReview(review),
                            child: Text(review == null ? 'Add' : 'Edit'),
                          ),
                          child: review == null
                              ? Text('No review yet', style: muted)
                              : Text(review, style: textTheme.bodyMedium),
                        ),
                      ],

                      if (hasPages && history.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SectionCard(
                          title: 'History',
                          trailing: TextButton(
                            onPressed: _addPreviousRead,
                            child: const Text('Add'),
                          ),
                          child: Column(
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

// Ten circles, 1 to 10. Circles up to the rating are filled.
// Tapping the current rating again clears it.
class _RatingRow extends StatelessWidget {
  final int? rating;
  final ValueChanged<int?> onChanged;

  const _RatingRow({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    final rating = this.rating ?? 0;

    return Row(
      children: [
        for (var n = 1; n <= 10; n++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AspectRatio(
                aspectRatio: 1,
                child: Material(
                  color: n <= rating
                      ? AppColors.secondary
                      : AppColors.secondarySoft,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(n == rating ? null : n),
                    child: Center(
                      child: Text(
                        '$n',
                        style: style?.copyWith(
                          color: n <= rating
                              ? AppColors.onSecondary
                              : AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// The main thing on the page: a white card with the page number, the
// slider and the reading pace, all in one place
class _ProgressCard extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final int percent;
  // Only a reading or paused read takes progress
  final bool active;
  final ({int days, int perDay, DateTime? finishBy})? pace;
  final VoidCallback onEditPage;
  final ValueChanged<int> onDrag;
  final ValueChanged<int> onDragEnd;
  // Set when the last page is saved but the book isn't finished yet
  final VoidCallback? onFinish;

  const _ProgressCard({
    required this.currentPage,
    required this.pageCount,
    required this.percent,
    required this.active,
    required this.pace,
    required this.onEditPage,
    required this.onDrag,
    required this.onDragEnd,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const faded = AppColors.textSecondary;
    final pace = this.pace;
    final onFinish = this.onFinish;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  active ? 'Current page' : 'Pages read',
                  style: textTheme.labelLarge?.copyWith(color: faded),
                ),
              ),
              Text(
                '$percent%',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Tap the number to type an exact page
              Expanded(
                child: GestureDetector(
                  onTap: active ? onEditPage : null,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentPage',
                        style: textTheme.displaySmall?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ $pageCount',
                        style: textTheme.titleMedium?.copyWith(color: faded),
                      ),
                    ],
                  ),
                ),
              ),
              // Spelled out, so a new user sees how to change the page
              if (active)
                FilledButton(
                  onPressed: onEditPage,
                  child: const Text('Update'),
                ),
            ],
          ),
          // Drag to move the page; saved when the finger lifts.
          // Ended reads show it but can't be dragged.
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              disabledActiveTrackColor: AppColors.primary,
              disabledInactiveTrackColor: AppColors.border,
              disabledThumbColor: AppColors.primary,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              // No side padding, so the track lines up with the text
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              value: currentPage.toDouble(),
              max: pageCount.toDouble(),
              onChanged: active ? (v) => onDrag(v.round()) : null,
              onChangeEnd: active ? (v) => onDragEnd(v.round()) : null,
            ),
          ),
          if (onFinish != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Mark as finished'),
            ),
          ],
          // Worked out from the start date and the page, so they cost no
          // extra reads; they follow the drag
          if (pace != null) ...[
            const Divider(height: 24, color: AppColors.border),
            Row(
              children: [
                _PaceStat(
                  value: '${pace.days}',
                  label: pace.days == 1 ? 'day reading' : 'days reading',
                ),
                _PaceStat(value: '${pace.perDay}', label: 'pages a day'),
                _PaceStat(
                  value: pace.finishBy == null ? '–' : dayMonth(pace.finishBy!),
                  label: 'finish by',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// One pace fact on the progress card: a bold value over a muted label
class _PaceStat extends StatelessWidget {
  final String value;
  final String label;

  const _PaceStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// A bordered list of small rows with thin lines between them
class _DetailsList extends StatelessWidget {
  final List<_DetailRow> rows;

  const _DetailsList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final row in rows) ...[
            row,
            // Starts after the icon, so the icons read as one column
            if (row != rows.last)
              const Divider(height: 1, indent: 52, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

// An icon, a line of text and an optional green action word on the right
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    final action = this.action;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodyMedium),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (action != null)
              Text(
                action,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// A small green word that sits inline with text, without a button's padding
class _InlineLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InlineLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
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
