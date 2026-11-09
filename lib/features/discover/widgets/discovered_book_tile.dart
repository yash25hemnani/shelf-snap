import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/taste_match.dart';
import 'package:shelf_snap/features/discover/widgets/match_pill.dart';

// One discovered book as a row: cover, title, author, where it was seen,
// and the match pill when there's one to show
class DiscoveredBookTile extends StatelessWidget {
  static const _coverWidth = 48.0;
  static const _coverHeight = 72.0;

  final DiscoveredBookModel item;
  final TasteMatch? match;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  // Picked for a bulk action: the cover shows a tick
  final bool selected;
  // When set, swiping left removes the book. Resolves true when the book
  // was removed, so the row slides away; false snaps it back.
  final Future<bool> Function()? onRemove;

  const DiscoveredBookTile({
    super.key,
    required this.item,
    this.match,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.onRemove,
  });

  // "Jaipur Book Fair, 3 Nov"; parts are left out when unknown
  String? get _seen {
    final parts = [
      ?item.lastPlace,
      if (item.lastSeenAt case final at?) dayMonth(at),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final match = this.match;
    final seen = _seen;
    final coverUrl = item.book.coverUrl;
    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(Icons.menu_book_rounded, color: AppColors.hint),
      ),
    );

    final tile = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: _coverWidth,
                height: _coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverUrl == null
                        ? placeholder
                        : Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => placeholder,
                          ),
                    if (selected)
                      ColoredBox(
                        color: AppColors.primary.withValues(alpha: 0.8),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.onPrimary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.book.authorLine ?? 'Unknown author',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (match != null || seen != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (match != null) ...[
                          MatchPill(match: match),
                          const SizedBox(width: 8),
                        ],
                        if (seen != null)
                          Expanded(
                            child: Text(
                              seen,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.hint,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final onRemove = this.onRemove;
    if (onRemove == null) return tile;

    // The parent must drop the book from its list once this resolves true,
    // or Flutter complains that a dismissed row is still in the tree
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => onRemove(),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.onPrimary,
        ),
      ),
      child: tile,
    );
  }
}
