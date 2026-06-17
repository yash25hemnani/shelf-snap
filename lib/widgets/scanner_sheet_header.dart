import 'package:flutter/material.dart';

/// Header for the draggable results sheet on [ScannerScreen]: the drag
/// handle, a result/capture count summary, and an inline "processing"
/// spinner while a capture is still being analyzed.
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(children: [
        // Drag handle hinting the sheet can be pulled up.
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[600],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$resultCount book${resultCount == 1 ? '' : 's'} found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (captureCount > 0)
              Text(
                '$captureCount photo${captureCount == 1 ? '' : 's'} scanned',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        if (isProcessing) ...[
          const SizedBox(height: 6),
          Row(children: [
            SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              activeProcessingCount == 1
                  ? 'Processing 1 capture...'
                  : 'Processing $activeProcessingCount captures...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
