import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

// One book in the reading list: cover, title, author, status and,
// while it's being read, a progress bar
class ReadingLogTile extends StatelessWidget {
  final ReadingLogModel log;

  const ReadingLogTile({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showProgress =
        log.status == BookStatus.reading || log.status == BookStatus.paused;

    const coverFallback = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(Icons.menu_book_rounded, color: AppColors.hint),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 48,
            height: 72,
            child: log.coverUrl == null
                ? coverFallback
                : Image.network(
                    log.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => coverFallback,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
              if (log.authors.isNotEmpty)
                Text(
                  log.authors.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                log.status.label,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: log.progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
