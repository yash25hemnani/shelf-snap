import 'package:flutter/material.dart';
import 'package:shelf_snap/services/match_scoring_service.dart';
import 'package:shelf_snap/widgets/book_cover_placeholder.dart';
import 'package:shelf_snap/widgets/confidence_badge.dart';

/// A single scanned book in the results list. Swipe left to remove it
/// (calls [onDismissed]) — used by [ScannerScreen]'s results sheet.
class BookResultCard extends StatelessWidget {
  final ScoredBookResult result;
  final int index;
  final VoidCallback onDismissed;

  const BookResultCard({
    super.key,
    required this.result,
    required this.index,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final book = result.book;
    return Dismissible(
      // Includes index because duplicate titles are otherwise possible
      // and Dismissible requires every key in the list to be unique.
      key: ValueKey('${book.title}_$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red[900],
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        dense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: book.coverUrl != null
              ? Image.network(
            book.coverUrl!,
            width: 36, height: 50, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const BookCoverPlaceholder(),
          )
              : const BookCoverPlaceholder(),
        ),
        title: Text(
          book.title,
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          book.author ?? 'Unknown author',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 70),
          child: ConfidenceBadge(score: result.score),
        ),
      ),
    );
  }
}
