import 'package:flutter/material.dart';

class ScannerSheetHeader extends StatelessWidget {
  final int resultCount;
  final int captureCount;
  final bool isProcessing;
  final int activeProcessingCount;

  const ScannerSheetHeader({
    super.key,
    required this.resultCount,
    required this.captureCount,
    required this.isProcessing,
    required this.activeProcessingCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDone = captureCount > 0 && !isProcessing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title row
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '$resultCount ${resultCount == 1 ? 'book' : 'books'} found',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isProcessing)
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: primary,
                        ),
                      )
                    else if (isDone)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                  ],
                ),
              ),
              if (captureCount > 0)
                Text(
                  '$captureCount ${captureCount == 1 ? 'photo' : 'photos'} scanned',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}