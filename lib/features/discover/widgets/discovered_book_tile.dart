import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/keyword_match.dart';
import 'package:shelf_snap/features/discover/models/taste_match.dart';
import 'package:shelf_snap/features/discover/widgets/highlighted_text.dart';
import 'package:shelf_snap/features/discover/widgets/match_pill.dart';

// One discovered book as a row: cover, title, author, where it was seen,
// and the match pill when there's one to show
class DiscoveredBookTile extends StatelessWidget {
  static const _coverWidth = 48.0;
  static const _coverHeight = 72.0;

  final DiscoveredBookModel item;
  final TasteMatch? match;
  // The reader's keywords this book matches (KeywordMatch.of)
  final List<String> keywordHits;
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
    this.keywordHits = const [],
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
    final hitWords = KeywordMatch.words(keywordHits);
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
                  HighlightedText(
                    item.book.title,
                    words: hitWords,
                    maxLines: 2,
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  HighlightedText(
                    item.book.authorLine ?? 'Unknown author',
                    words: item.book.authors.isEmpty ? const {} : hitWords,
                    maxLines: 1,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (keywordHits.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            keywordHits.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
