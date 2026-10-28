import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/widgets/status_dropdown.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
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
      messenger.showError("Couldn't update status, check your connection");
    }
  }

  // Pages when the book has a page count, otherwise a percent
  Future<void> _editProgress(ReadingLogModel log, ReadModel read) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    final pageCount = log.pageCount;
    final usePages = pageCount != null && pageCount > 0;
    final unit = usePages ? ProgressUnit.pages : ProgressUnit.percent;

    final value = await showNumberDialog(
      context,
      title: usePages ? 'Current page' : 'Percent read',
      // Only prefill when the saved value is in the same unit
      initial: read.progressUnit == unit ? read.progressValue : null,
      max: usePages ? pageCount : 100,
    );
    if (value == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateProgess(value, unit, widget.readingKey, userId);
    } catch (e) {
      messenger.showError("Couldn't save progress, check your connection");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final logAsync = ref.watch(readingLogProvider(widget.readingKey));

    return Scaffold(
      appBar: AppBar(),
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
          final coverUrl = log.coverUrl;
          const placeholder = ColoredBox(
            color: AppColors.surfaceMuted,
            child: Center(
              child: Icon(Icons.book, size: 40, color: AppColors.hint),
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 96,
                        height: 144,
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
                          if (log.pageCount != null)
                            Text('${log.pageCount} pages', style: muted),
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

                // Want to read has no read, so no progress or dates
                if (read != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Progress', style: textTheme.titleMedium),
                      ),
                      // Only a reading or paused read takes progress
                      if (read.isActive)
                        TextButton(
                          onPressed: () => _editProgress(log, read),
                          child: const Text('Update'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(switch (read.progressUnit) {
                    ProgressUnit.percent => '${read.progressValue}%',
                    ProgressUnit.pages =>
                      log.pageCount == null
                          ? 'Page ${read.progressValue}'
                          : 'Page ${read.progressValue} of ${log.pageCount}',
                  }, style: muted),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: read.fraction(log.pageCount) ?? 0,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceMuted,
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Dates', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Text('Started')),
                      Text(read.startedAt?.label ?? 'Not set', style: muted),
                    ],
                  ),
                  // Only an ended read has an end date
                  if (!read.isActive) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            read.status == BookStatus.dnf
                                ? 'Stopped'
                                : 'Finished',
                          ),
                        ),
                        Text(read.endedAt?.label ?? 'Not set', style: muted),
                      ],
                    ),
                  ],
                ],
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
