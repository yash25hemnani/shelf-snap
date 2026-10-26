import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/widgets/status_dropdown.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final BookModel book;
  final VoidCallback? onAdd; // null = hide the button
  const BookDetailScreen({super.key, required this.book, this.onAdd});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  // The log stream shows the new status as soon as it's written locally
  Future<void> _onStatusChanged(BookStatus status) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateBookStatus(status, widget.book, userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = widget.book.coverUrl;
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

    // Books without a title or author have no key, so they can't be tracked
    final readingKey = widget.book.readingKey;
    final status = readingKey == null
        ? null
        : ref.watch(readingLogProvider(readingKey)).valueOrNull?.status;

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
                      Text(
                        widget.book.title,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (widget.book.subtitle != null)
                        Text(
                          widget.book.subtitle!,
                          style: theme.textTheme.titleSmall,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        widget.book.authorLine ?? 'Unknown author',
                        style: muted,
                      ),
                      const SizedBox(height: 12),
                      if (widget.book.publisher != null)
                        Text(widget.book.publisher!, style: muted),
                      if (widget.book.publishedDate != null)
                        Text(
                          'Published ${widget.book.publishedDate}',
                          style: muted,
                        ),
                      if (widget.book.pageCount != null)
                        Text('${widget.book.pageCount} pages', style: muted),
                      if (widget.book.language != null)
                        Text(
                          'Language: ${widget.book.language!.toUpperCase()}',
                          style: muted,
                        ),
                      if (widget.book.isbn != null)
                        Text('ISBN ${widget.book.isbn}', style: muted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StatusDropdown(
              value: status,
              onChanged: readingKey == null ? null : _onStatusChanged,
            ),

            if (widget.book.categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in widget.book.categories)
                    Chip(label: Text(category)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(widget.book.description ?? 'No summary available.'),
          ],
        ),
      ),
      bottomNavigationBar: widget.onAdd == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text("Add to Library"),
                ),
              ),
            ),
    );
  }
}
