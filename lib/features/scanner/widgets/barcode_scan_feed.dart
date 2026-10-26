import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';
import 'package:shelf_snap/features/scanner/providers/barcode_session_provider.dart';

/// The newest barcode scans over the camera, each showing its lookup
/// progress. [highlightIsbn] marks a scan that was just scanned again.
class BarcodeScanFeed extends ConsumerWidget {
  final String? highlightIsbn;

  const BarcodeScanFeed({super.key, this.highlightIsbn});

  static const _maxRows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Map keeps scan order, so the last entries are the newest
    final hits = ref.watch(barcodeSessionProvider).values.toList();
    final recent = hits.reversed.take(_maxRows).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hit in recent)
          Padding(
            key: ValueKey(hit.isbn),
            padding: const EdgeInsets.only(bottom: 8),
            child: _FeedRow(
              hit: hit,
              highlighted: hit.isbn == highlightIsbn,
            ),
          ),
      ],
    );
  }
}

class _FeedRow extends StatelessWidget {
  final BarcodeHit hit;
  final bool highlighted;

  const _FeedRow({required this.hit, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final book = hit.book;

    final (Widget leading, String title, String subtitle) = switch (hit.status) {
      HitStatus.loading => (
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
        'Looking up…',
        hit.isbn,
      ),
      HitStatus.found => (
        _Cover(url: book?.coverUrl),
        book?.title ?? hit.isbn,
        book?.authorLine ?? hit.isbn,
      ),
      HitStatus.notFound => (
        const Icon(Icons.help_outline_rounded, color: Colors.amberAccent),
        'No match for this ISBN',
        hit.isbn,
      ),
      HitStatus.failed => (
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
        'Lookup failed, scan it again',
        hit.isbn,
      ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? Colors.white : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  highlighted ? 'Already scanned' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (hit.status == HitStatus.found)
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;

  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.menu_book_rounded, color: Colors.white);
    final coverUrl = url;
    if (coverUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        coverUrl,
        width: 28,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
