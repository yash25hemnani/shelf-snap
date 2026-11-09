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
// already saved to Discovered, so there's no Save button here.
class DiscoverResultsSheet extends ConsumerWidget {
  final List<DiscoveredBookModel> books;

  const DiscoverResultsSheet({super.key, required this.books});

  static Future<void> show(
    BuildContext context, {
    required List<DiscoveredBookModel> books,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DiscoverResultsSheet(books: books),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    onPressed: () => _push(context, const DiscoveredScreen()),
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
                        context,
                        DiscoveredBookScreen(
                          readingKey: item.id,
                          initial: item,
                        ),
                      ),
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
