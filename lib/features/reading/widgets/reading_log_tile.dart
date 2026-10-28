import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

// One book on the reading list: cover, title, author, status and progress
class ReadingLogTile extends StatelessWidget {
  final ReadingLogModel log;
  final VoidCallback? onTap;

  const ReadingLogTile({super.key, required this.log, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final coverUrl = log.coverUrl;
    final read = log.latestRead;

    final statusColor = switch (log.status) {
      BookStatus.reading => AppColors.accent,
      BookStatus.paused => AppColors.warning,
      BookStatus.finished => AppColors.primary,
      BookStatus.wantToRead || BookStatus.dnf => AppColors.textSecondary,
    };

    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, color: AppColors.hint)),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  log.title,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  log.authors.isEmpty
                      ? 'Unknown author'
                      : log.authors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  log.status.label,
                  style: textTheme.labelMedium?.copyWith(color: statusColor),
                ),
                // Want to read has no read, so no bar
                if (read != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      // Null when pages are used but the page count is unknown
                      value: read.fraction(log.pageCount) ?? 0,
                      minHeight: 4,
                      color: statusColor,
                      backgroundColor: AppColors.surfaceMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
