import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

class BookDetailScreen extends StatelessWidget {
  final BookModel book;
  final VoidCallback? onAdd; // null = hide the button
  const BookDetailScreen({super.key, required this.book, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = book.coverUrl;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final placeholder = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.book,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: coverUrl == null
                          ? placeholder
                          : Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  placeholder,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: theme.textTheme.titleLarge),
                      if (book.subtitle != null)
                        Text(book.subtitle!, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(book.authorLine ?? 'Unknown author', style: muted),
                      const SizedBox(height: 12),
                      if (book.publisher != null)
                        Text(book.publisher!, style: muted),
                      if (book.publishedDate != null)
                        Text('Published ${book.publishedDate}', style: muted),
                      if (book.pageCount != null)
                        Text('${book.pageCount} pages', style: muted),
                      if (book.language != null)
                        Text(
                          'Language: ${book.language!.toUpperCase()}',
                          style: muted,
                        ),
                      if (book.isbn != null)
                        Text('ISBN ${book.isbn}', style: muted),
                    ],
                  ),
                ),
              ],
            ),
            if (book.categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in book.categories)
                    Chip(label: Text(category)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(book.description ?? 'No summary available.'),
          ],
        ),
      ),
      bottomNavigationBar: onAdd == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text("Add to Library"),
                ),
              ),
            ),
    );
  }
}
