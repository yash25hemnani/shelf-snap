import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

class BookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback? onTap;

  const BookCard({super.key, required this.book, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = book.authorLine;
    final coverUrl = book.coverUrl;

    final placeholder = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.book, color: theme.colorScheme.onSurfaceVariant),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl == null
                      ? placeholder
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              placeholder,
                        ),
                  // Only editors get private books, so only they see this
                  if (book.isPrivate)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.text,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Always present so every card's text block is the same height
          Text(
            author ?? 'Unknown author',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
