import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/taste_match.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';
import 'package:shelf_snap/features/discover/screens/discovered_book_screen.dart';
import 'package:shelf_snap/features/discover/screens/discovered_screen.dart';
import 'package:shelf_snap/features/discover/widgets/discovered_book_tile.dart';

// The books found since the scanner opened, best match first. They're
// already saved to Discovered, so there's no Save button here; a wrong
// spot is swiped away instead.
class DiscoverResultsSheet extends ConsumerStatefulWidget {
  final List<DiscoveredBookModel> books;
  // Lets the scanner drop the book from its own list too, so it doesn't
  // come back when the sheet is reopened
  final ValueChanged<DiscoveredBookModel> onRemoved;

  const DiscoverResultsSheet({
    super.key,
    required this.books,
    required this.onRemoved,
  });

  static Future<void> show(
    BuildContext context, {
    required List<DiscoveredBookModel> books,
    required ValueChanged<DiscoveredBookModel> onRemoved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DiscoverResultsSheet(books: books, onRemoved: onRemoved),
    );
  }

  @override
  ConsumerState<DiscoverResultsSheet> createState() =>
      _DiscoverResultsSheetState();
}

class _DiscoverResultsSheetState extends ConsumerState<DiscoverResultsSheet> {
  late List<DiscoveredBookModel> _books = widget.books;

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // Dismissible needs the row gone from the list once it slides away
  Future<bool> _remove(DiscoveredBookModel item) async {
    final removed = await DiscoveredBookScreen.confirmRemove(
      context,
      ref,
      item,
    );
    if (!removed) return false;

    widget.onRemoved(item);
    if (!mounted) return true;
    final left = _books.where((b) => b.id != item.id).toList();
    if (left.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() => _books = left);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final books = _books;
    final textTheme = Theme.of(context).textTheme;
    final taste =
        (ref.watch(discoverSettingsProvider).valueOrNull ??
                const DiscoverSettingsModel())
            .genres;

    // Best match first, keeping the newest-first order within each match.
    // null is last: it's every book when no genres are picked.
    final rows = [
      for (final match in [...TasteMatch.values, null])
        for (final item in books)
          if (TasteMatch.of(taste, item.genres) == match) (item, match),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          books.length == 1
                              ? '1 book found'
                              : '${books.length} books found',
                          style: textTheme.titleMedium,
                        ),
                        Text(
                          'Saved to Discovered',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _push(const DiscoveredScreen()),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final (item, match) in rows)
                    DiscoveredBookTile(
                      item: item,
                      match: match,
                      onTap: () => _push(
                        DiscoveredBookScreen(readingKey: item.id, initial: item),
                      ),
                      onRemove: () => _remove(item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
