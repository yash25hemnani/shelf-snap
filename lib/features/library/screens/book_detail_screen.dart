import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/widgets/language_sheet.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/languages.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/section_card.dart';
import 'package:shelf_snap/core/widgets/text_dialog.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/widgets/status_dropdown.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
import 'package:shelf_snap/features/reading/screens/reading_log_detail_screen.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final BookModel book;
  // Opens the save sheet; resolves to true once saved. Null hides the button.
  final Future<bool> Function()? onAdd;
  const BookDetailScreen({super.key, required this.book, this.onAdd});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _removing = false;
  bool _summaryExpanded = false;
  bool _added = false; // saved from this page, so Add is turned off

  Future<void> _add(Future<bool> Function() onAdd) async {
    final saved = await onAdd();
    if (saved && mounted) setState(() => _added = true);
  }

  // Removes one copy, or the whole book when it's the last copy
  Future<void> _remove() async {
    final book = widget.book;
    final libraryId = book.libraryId;
    final bookId = book.id;

    if (libraryId == null || bookId == null || _removing) return;

    setState(() => _removing = true);
    try {
      await ref.read(libraryRepositoryProvider).deleteBook(libraryId, bookId);
      if (!mounted) return;

      // Shown before popping; the app-wide messenger keeps it on screen
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              book.noOfCopies > 1
                  ? 'Removed one copy of ${book.title}'
                  : 'Removed ${book.title} from library',
            ),
          ),
        );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _removing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text("Couldn't remove book, check your connection"),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  // The log stream shows the new status as soon as it's written locally
  Future<void> _onStatusChanged(BookStatus status) async {
    final userId = AuthService().currentUser?.uid;
    final readingKey = widget.book.readingKey;
    if (userId == null || readingKey == null) return;

    // Picking the current status isn't a blocked move, so skip it here
    final current = ref
        .read(readingLogProvider(readingKey))
        .valueOrNull
        ?.status;
    if (status == current) return;

    try {
      final saved = await ref
          .read(readingLogRepositoryProvider)
          .updateStatus(status, widget.book, userId);
      if (!saved && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showMessage("Can't move this book back to ${status.label}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showError("Couldn't update status, check your connection");
    }
  }

  // Asks how the copy was acquired; the live book shows the saved text
  Future<void> _editAcquisition(String? current) async {
    final libraryId = widget.book.libraryId;
    final bookId = widget.book.id;

    if (libraryId == null || bookId == null) return;

    final text = await showTextDialog(
      context,
      title: 'Acquired',
      initial: current,
      hint: 'Bought at Crossword',
      suggestions: const ['Bought', 'Gift from', 'Borrowed from'],
    );
    if (text == null || !mounted) return; // cancelled

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateAcquisition(libraryId, bookId, text);
    } catch (e) {
      debugPrint('updateAcquisition failed: $e');
      messenger.showError("Couldn't save, check your connection");
    }
  }

  Future<void> _editOriginalLanguage(String? current) async {
    final libraryId = widget.book.libraryId;
    final bookId = widget.book.id;

    if (libraryId == null || bookId == null) return;

    final code = await showLanguageSheet(
      context,
      title: "Original language",
      current: current,
    );

    if (code == null || !mounted) return; // dismissed

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateOriginalLanguage(
            libraryId,
            bookId,
            code.isEmpty ? null : code,
          );
    } catch (e) {
      debugPrint('updateOriginalLanguage failed: $e');
      messenger.showError("Couldn't save, check your connection");
    }
  }

  void _openLog(String readingKey) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingLogDetailScreen(readingKey: readingKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Saved books follow their doc, so edits show straight away.
    // Search books have no ids and show what was passed in.
    final libraryId = widget.book.libraryId;
    final bookId = widget.book.id;
    final live = libraryId == null || bookId == null
        ? null
        : ref
              .watch(
                libraryBookProvider((libraryId: libraryId, bookId: bookId)),
              )
              .valueOrNull;
    final book = live ?? widget.book;

    // Only editors see and change the copy's details. False for search
    // books and while the library loads.
    final library = libraryId == null
        ? null
        : ref.watch(libraryProvider(libraryId)).valueOrNull;
    final canEdit = library?.canEdit(AuthService().currentUser?.uid) ?? false;

    // Books without a title or author have no key, so they can't be tracked
    final readingKey = book.readingKey;
    final log = readingKey == null
        ? null
        : ref.watch(readingLogProvider(readingKey)).valueOrNull;

    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    // Google Books sends 0 when it doesn't know
    final pageCount = (book.pageCount ?? 0) > 0 ? book.pageCount : null;
    final description = book.description;
    // The original language only adds something when this edition differs
    final original = book.originalLanguage;
    final translatedFrom =
        original != null && original != book.language?.toLowerCase()
        ? original
        : null;
    final hasDetails =
        book.publisher != null ||
        book.publishedDate != null ||
        book.language != null ||
        translatedFrom != null ||
        book.isbn != null;

    final coverUrl = book.coverUrl;
    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, size: 40, color: AppColors.hint)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
        // A thin line between the bar and the page
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          // Only saved books opened from a library can be removed
          if (bookId != null && libraryId != null)
            PopupMenuButton<void>(
              enabled: !_removing,
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: _remove,
                  child: const ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Remove from library',
                      style: TextStyle(color: AppColors.error),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 128,
                      height: 192,
                      child: coverUrl == null
                          ? placeholder
                          : Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => placeholder,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title, style: textTheme.titleLarge),
                        if (book.subtitle != null)
                          Text(book.subtitle!, style: textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(book.authorLine ?? 'Unknown author', style: muted),
                        if (pageCount != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text('$pageCount pages', style: muted),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        StatusDropdown(
                          value: log?.status,
                          onChanged: readingKey == null
                              ? null
                              : _onStatusChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Only books on the reading list have something to show
                  if (log != null && readingKey != null) ...[
                    SectionCard(
                      icon: Icons.bar_chart_rounded,
                      title: 'Your reading',
                      trailing: TextButton(
                        onPressed: () => _openLog(readingKey),
                        child: const Text('Open Log'),
                      ),
                      child: _ReadingSummary(log: log),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (hasDetails) ...[
                    SectionCard(
                      icon: Icons.info_outline_rounded,
                      title: 'Details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (book.publisher != null)
                            _InfoRow(label: 'Publisher', value: book.publisher),
                          if (book.publishedDate != null)
                            _InfoRow(
                              label: 'Published',
                              value: book.publishedDate,
                            ),
                          if (book.language case final language?)
                            _InfoRow(
                              label: 'Language',
                              value: languageName(language),
                            ),
                          if (translatedFrom != null)
                            _InfoRow(
                              label: 'Translated from',
                              value: languageName(translatedFrom),
                            ),
                          if (book.isbn != null)
                            _InfoRow(label: 'ISBN', value: book.isbn),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (book.categories.isNotEmpty) ...[
                    SectionCard(
                      icon: Icons.local_offer_outlined,
                      title: 'Genres',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in book.categories)
                            Chip(label: Text(category)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Only editors see the copy's details. Each row is
                  // tapped to edit, so more fields can join it later.
                  if (canEdit) ...[
                    SectionCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Your copy',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InfoRow(
                            label: 'Acquired',
                            value: book.acquisition,
                            placeholder: 'Add',
                            onTap: () => _editAcquisition(book.acquisition),
                          ),
                          _InfoRow(
                            label: 'Original language',
                            value: switch (book.originalLanguage) {
                              null => null,
                              final code => languageName(code),
                            },
                            placeholder: 'Add',
                            onTap: () =>
                                _editOriginalLanguage(book.originalLanguage),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SectionCard(
                    icon: Icons.notes_rounded,
                    title: 'Summary',
                    child: description == null
                        ? Text('No summary available.', style: muted)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                maxLines: _summaryExpanded ? null : 4,
                                overflow: _summaryExpanded
                                    ? null
                                    : TextOverflow.ellipsis,
                              ),
                              // Short summaries fit in four lines anyway
                              if (description.length > 200)
                                TextButton(
                                  onPressed: () => setState(
                                    () => _summaryExpanded = !_summaryExpanded,
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 36),
                                  ),
                                  child: Text(
                                    _summaryExpanded
                                        ? 'Show less'
                                        : 'Read more',
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: switch (widget.onAdd) {
        null => null,
        final onAdd => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              // Off once saved, so a second tap can't add another copy
              onPressed: _added ? null : () => _add(onAdd),
              icon: Icon(_added ? Icons.check_rounded : Icons.add),
              label: Text(_added ? 'Added' : 'Add to Library'),
            ),
          ),
        ),
      },
    );
  }
}

// A label on the left and its value on the right. With onTap, the row
// can be tapped to edit and shows the placeholder when there's no value.
class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.label,
    required this.value,
    this.placeholder = 'Not set',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final value = this.value;
    final onTap = this.onTap;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: textTheme.bodyMedium),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value ?? placeholder,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                color: value == null && onTap != null
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

// The latest read in one line, with a bar when progress is known
class _ReadingSummary extends StatelessWidget {
  final ReadingLogModel log;

  const _ReadingSummary({required this.log});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    final read = log.latestRead;

    // Want to read has no read yet
    if (read == null) {
      return Text('On your Want to read list', style: muted);
    }

    final fraction = read.fraction(log.pageCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(log.status.label, style: muted)),
            if (fraction != null)
              SoftPill(label: '${(fraction * 100).round()}%'),
          ],
        ),
        if (fraction != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          ),
        ],
      ],
    );
  }
}
