import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';
import 'package:shelf_snap/features/scanner/providers/barcode_session_provider.dart';

/// White card on the barcode camera: a log of each scan, newest first.
/// It only adds and updates lines, so removing or saving books in the
/// results sheet leaves the log as it is.
/// [highlightIsbn] marks a scan that was just scanned again.
class BarcodeStatusCard extends ConsumerStatefulWidget {
  final String? highlightIsbn;

  const BarcodeStatusCard({super.key, this.highlightIsbn});

  @override
  ConsumerState<BarcodeStatusCard> createState() => _BarcodeStatusCardState();
}

class _BarcodeStatusCardState extends ConsumerState<BarcodeStatusCard> {
  // Newest first; the id keeps each line's key unique when an ISBN is
  // scanned again after a failed lookup
  final _log = <({int id, BarcodeHit hit})>[];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    // Scans made before the card was shown, e.g. after switching back
    for (final hit in ref.read(barcodeSessionProvider).values) {
      _log.insert(0, (id: _nextId++, hit: hit));
    }
  }

  // A hit is a new object only when it was just added or its lookup finished
  void _onSessionChanged(
    Map<String, BarcodeHit>? previous,
    Map<String, BarcodeHit> next,
  ) {
    for (final hit in next.values) {
      if (identical(previous?[hit.isbn], hit)) continue;

      final i = _log.indexWhere(
        (e) => e.hit.isbn == hit.isbn && e.hit.status == HitStatus.loading,
      );
      setState(() {
        if (hit.status != HitStatus.loading && i >= 0) {
          _log[i] = (id: _log[i].id, hit: hit);
        } else {
          _log.insert(0, (id: _nextId++, hit: hit));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(barcodeSessionProvider, _onSessionChanged);

    final textTheme = Theme.of(context).textTheme;
    final highlightIsbn = widget.highlightIsbn;
    // Only the newest line for the ISBN is highlighted
    final highlightIndex = highlightIsbn == null
        ? -1
        : _log.indexWhere((e) => e.hit.isbn == highlightIsbn);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Recent scans', style: textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Scanned: ${_log.length}',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _log.isEmpty
                ? Center(
                    child: Text(
                      'Point at the barcode on the back cover',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _log.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) => _StatusRow(
                      key: ValueKey(_log[i].id),
                      hit: _log[i].hit,
                      highlighted: i == highlightIndex,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final BarcodeHit hit;
  final bool highlighted;

  const _StatusRow({super.key, required this.hit, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final book = hit.book;

    final (
      Widget leading,
      String title,
      String subtitle,
      Widget? trailing,
    ) = switch (hit.status) {
      HitStatus.loading => (
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
        'Looking up…',
        hit.isbn,
        null,
      ),
      HitStatus.found => (
        _Cover(url: book?.coverUrl),
        book?.title ?? hit.isbn,
        book?.authorLine ?? hit.isbn,
        const Icon(Icons.check_circle_rounded, color: AppColors.success),
      ),
      HitStatus.notFound => (
        const Icon(Icons.help_outline_rounded, color: AppColors.warning),
        'No match for this ISBN',
        hit.isbn,
        null,
      ),
      HitStatus.failed => (
        const Icon(Icons.error_outline_rounded, color: AppColors.error),
        'Lookup failed, scan it again',
        hit.isbn,
        null,
      ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: highlighted ? AppColors.primarySoft : AppColors.background,
      child: ListTile(
        leading: SizedBox(width: 32, child: Center(child: leading)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          highlighted ? 'Already scanned' : subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;

  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.menu_book_rounded, color: AppColors.hint);
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
