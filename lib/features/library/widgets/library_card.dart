import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

class LibraryCard extends StatelessWidget {
  final LibraryModel library;
  final VoidCallback? onTap;

  const LibraryCard({super.key, required this.library, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = library.description;

    final memberCount = library.members.length;
    final bookCount = library.bookCount; 

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover placeholder (later: Image.network(library.coverUrl!))
            Container(
              width: 80,
              height: 110,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.menu_book,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      library.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '$bookCount books · $memberCount ${memberCount == 1 ? 'member' : 'members'}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
