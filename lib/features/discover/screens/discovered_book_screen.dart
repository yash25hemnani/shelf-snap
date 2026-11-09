import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/core/widgets/section_card.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/taste_match.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';
import 'package:shelf_snap/features/discover/sheets/discover_genres_sheet.dart';
import 'package:shelf_snap/features/discover/widgets/match_pill.dart';
import 'package:shelf_snap/features/library/models/genre.dart';
import 'package:shelf_snap/features/library/sheets/save_to_library_sheet.dart';
import 'package:shelf_snap/features/library/widgets/wikipedia_card.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';

// One discovered book: how it matches your genres, where you saw it, and
// buttons to keep it (Want to read, Add to library) or remove it
class DiscoveredBookScreen extends ConsumerStatefulWidget {
  final String readingKey;
  // Shown until the doc loads, e.g. straight after a scan
  final DiscoveredBookModel? initial;

  const DiscoveredBookScreen({
    super.key,
    required this.readingKey,
    this.initial,
  });

  // Asks first, then deletes without waiting so it works offline. True when
  // the delete was started, which lets a swiped row slide away.
  static Future<bool> confirmRemove(
    BuildContext context,
    WidgetRef ref,
    DiscoveredBookModel item,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove this book?',
      message: '${item.book.title} will be removed from Discovered.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (!confirmed || userId == null || !context.mounted) return false;

    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      ref
          .read(discoverRepositoryProvider)
          .deleteBook(userId, item.id)
          .catchError((Object e) {
            debugPrint('deleteBook failed: $e');
            messenger.showError("Couldn't remove this book");
          }),
    );
    messenger.showMessage('Removed ${item.book.title}');
    return true;
  }

  @override
  ConsumerState<DiscoveredBookScreen> createState() =>
      _DiscoveredBookScreenState();
}

class _DiscoveredBookScreenState extends ConsumerState<DiscoveredBookScreen> {
  bool _summaryExpanded = false;
  bool _savingStatus = false;

  Future<void> _wantToRead(DiscoveredBookModel item) async {
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (userId == null || _savingStatus) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingStatus = true);
    try {
      await ref
          .read(readingLogRepositoryProvider)
          .updateStatus(BookStatus.wantToRead, item.book, userId);
      messenger.showMessage('Added to Want to read');
    } catch (e) {
      debugPrint('updateStatus failed: $e');
      messenger.showError("Couldn't add it, check your connection");
    }
    if (mounted) setState(() => _savingStatus = false);
  }

  Future<void> _remove(DiscoveredBookModel item) async {
    final removed = await DiscoveredBookScreen.confirmRemove(
      context,
      ref,
      item,
    );
    if (removed && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bookAsync = ref.watch(discoveredBookProvider(widget.readingKey));
    final settings =
        ref.watch(discoverSettingsProvider).valueOrNull ??
        const DiscoverSettingsModel();
    final log = ref.watch(readingLogProvider(widget.readingKey)).valueOrNull;

    // A loaded null means the book was removed; while loading, use initial
    final item = bookAsync.hasValue ? bookAsync.value : widget.initial;

    final appBar = AppBar(
      title: const Text('Discovered book'),
      titleTextStyle: textTheme.titleMedium,
      titleSpacing: 0,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      actions: [
        if (item != null)
          // onSelected runs after the menu closes, so the dialog can open
          PopupMenuButton<bool>(
            onSelected: (_) => _remove(item),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: true,
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Remove from Discovered',
                    style: TextStyle(color: AppColors.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        const SizedBox(width: 4),
      ],
    );

    if (item == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: bookAsync.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  'This book is no longer in Discovered',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
      );
    }

    final book = item.book;
    final match = TasteMatch.of(settings.genres, item.genres);
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final description = book.description;
    final coverUrl = book.coverUrl;
    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, size: 40, color: AppColors.hint)),
    );

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 112,
                    height: 168,
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
                      if (book.subtitle case final subtitle?)
                        Text(subtitle, style: textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(book.authorLine ?? 'Unknown author', style: muted),
                      if (match != null) ...[
                        const SizedBox(height: 12),
                        MatchPill(match: match),
                      ],
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
                SectionCard(
                  icon: Icons.local_offer_outlined,
                  title: 'Genres',
                  trailing: TextButton(
                    onPressed: () =>
                        showDiscoverGenresSheet(context, ref, settings),
                    child: Text(
                      settings.hasGenres ? 'Your genres' : 'Pick yours',
                    ),
                  ),
                  child: item.genres.isEmpty
                      ? Text(
                          "The scan couldn't tell this book's genre",
                          style: muted,
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final genre in item.genres)
                              _GenreBadge(
                                genre: genre,
                                yours: settings.genres.contains(genre),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  icon: Icons.place_outlined,
                  title: 'Where you saw it',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoRow(
                        label: 'Places',
                        value: item.places.isEmpty
                            ? 'No place set'
                            : item.places.join(', '),
                      ),
                      if (item.lastSeenAt case final at?)
                        _InfoRow(label: 'Last seen', value: dayMonth(at)),
                      _InfoRow(
                        label: 'Seen',
                        value: item.seenCount == 1
                            ? 'Once'
                            : '${item.seenCount} times',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                WikipediaCard(book: book),
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
                                  _summaryExpanded ? 'Show less' : 'Read more',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  // Once it has a log, the status shows here instead
                  onPressed: log != null || _savingStatus
                      ? null
                      : () => _wantToRead(item),
                  icon: Icon(
                    log == null
                        ? Icons.bookmark_add_outlined
                        : Icons.bookmark_added_rounded,
                  ),
                  label: Text(log?.status.label ?? 'Want to read'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => SaveToLibrarySheet.show(context, book: book),
                  icon: const Icon(Icons.add),
                  label: const Text('Add to library'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A book's genre. Filled with the genre's colour when it's one of yours,
// outlined when it isn't, so the overlap is visible at a glance.
class _GenreBadge extends StatelessWidget {
  final Genre genre;
  final bool yours;

  const _GenreBadge({required this.genre, required this.yours});

  @override
  Widget build(BuildContext context) {
    final fill =
        AppColors.genreFills[genre.index % AppColors.genreFills.length];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: BoxDecoration(
        color: yours ? fill : AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: yours ? fill : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(genre.icon, size: 16, color: yours ? AppColors.onPrimary : fill),
          const SizedBox(width: 6),
          Text(
            genre.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: yours ? AppColors.onPrimary : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

// A label on the left and its value on the right
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodyMedium),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
