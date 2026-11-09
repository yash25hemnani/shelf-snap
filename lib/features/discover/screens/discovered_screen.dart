import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/taste_match.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';
import 'package:shelf_snap/features/discover/screens/discovered_book_screen.dart';
import 'package:shelf_snap/features/discover/sheets/discover_genres_sheet.dart';
import 'package:shelf_snap/features/discover/widgets/discovered_book_tile.dart';
import 'package:shelf_snap/features/library/sheets/genre_picker_sheet.dart';

// Every book found in Discover mode (the latest 50), grouped by how well
// it matches your genres, with genre and place filters on top
class DiscoveredScreen extends ConsumerWidget {
  const DiscoveredScreen({super.key});

  Future<void> _pickGenreFilter(BuildContext context, WidgetRef ref) async {
    final current = ref.read(discoveredGenreFilterProvider);
    final picked = await GenrePickerSheet.show(
      context,
      title: 'Filter by genre',
      selected: {?current},
      max: 1,
      actionLabel: 'Show books',
    );
    if (picked == null) return;
    ref.read(discoveredGenreFilterProvider.notifier).state = picked.firstOrNull;
  }

  void _togglePlace(WidgetRef ref, String place) {
    final notifier = ref.read(discoveredPlaceFilterProvider.notifier);
    notifier.state = notifier.state == place ? null : place;
  }

  void _clearFilters(WidgetRef ref) {
    ref.read(discoveredGenreFilterProvider.notifier).state = null;
    ref.read(discoveredPlaceFilterProvider.notifier).state = null;
  }

  void _open(BuildContext context, DiscoveredBookModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DiscoveredBookScreen(readingKey: item.id, initial: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final settings =
        ref.watch(discoverSettingsProvider).valueOrNull ??
        const DiscoverSettingsModel();
    final booksAsync = ref.watch(discoveredBooksProvider);
    final genre = ref.watch(discoveredGenreFilterProvider);
    final place = ref.watch(discoveredPlaceFilterProvider);
    final filtered = genre != null || place != null;

    // Recent places, plus the filtered one if it has dropped off the list
    final places = [
      ...settings.recentPlaces,
      if (place != null && !settings.recentPlaces.contains(place)) place,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovered'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          TextButton.icon(
            onPressed: () => showDiscoverGenresSheet(context, ref, settings),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(
              settings.hasGenres
                  ? 'Your genres · ${settings.genres.length}'
                  : 'Your genres',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Center(
                  child: FilterChip(
                    avatar: genre == null
                        ? const Icon(Icons.local_offer_outlined, size: 18)
                        : Icon(genre.icon, size: 18),
                    label: Text(genre?.label ?? 'Any genre'),
                    selected: genre != null,
                    showCheckmark: false,
                    onSelected: (_) => _pickGenreFilter(context, ref),
                  ),
                ),
                for (final p in places)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Center(
                      child: FilterChip(
                        avatar: const Icon(Icons.place_outlined, size: 18),
                        label: Text(p),
                        selected: p == place,
                        showCheckmark: false,
                        onSelected: (_) => _togglePlace(ref, p),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: booksAsync.when(
              data: (books) {
                if (books.isEmpty) {
                  return _Empty(
                    filtered: filtered,
                    onClear: () => _clearFilters(ref),
                  );
                }
                return _BookList(
                  books: books,
                  settings: settings,
                  onOpen: (item) => _open(context, item),
                  onPickGenres: () =>
                      showDiscoverGenresSheet(context, ref, settings),
                );
              },
              error: (e, _) {
                debugPrint('watchDiscovered failed: $e');
                return Center(
                  child: Text(
                    "Couldn't load your discovered books",
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

// The books grouped best match first, newest first within a group. With no
// genres picked there's nothing to group by, so it's newest first with a
// nudge to pick some.
class _BookList extends StatelessWidget {
  final List<DiscoveredBookModel> books;
  final DiscoverSettingsModel settings;
  final ValueChanged<DiscoveredBookModel> onOpen;
  final VoidCallback onPickGenres;

  const _BookList({
    required this.books,
    required this.settings,
    required this.onOpen,
    required this.onPickGenres,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!settings.hasGenres) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _PickGenresCard(onTap: onPickGenres),
          for (final item in books)
            DiscoveredBookTile(item: item, onTap: () => onOpen(item)),
        ],
      );
    }

    // books arrive newest first, and each group keeps that order
    final groups = <TasteMatch, List<DiscoveredBookModel>>{
      for (final match in TasteMatch.values) match: [],
    };
    for (final item in books) {
      groups[TasteMatch.of(settings.genres, item.genres)]!.add(item);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final MapEntry(key: match, value: items) in groups.entries)
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(match.heading, style: textTheme.titleSmall),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length}',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.hint,
                    ),
                  ),
                ],
              ),
            ),
            // The group heading already says the match
            for (final item in items)
              DiscoveredBookTile(item: item, onTap: () => onOpen(item)),
          ],
      ],
    );
  }
}

class _PickGenresCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PickGenresCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sort by your taste', style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Pick the genres you like and the best matches go first',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Pick genres'),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool filtered;
  final VoidCallback onClear;

  const _Empty({required this.filtered, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered
                  ? Icons.filter_alt_off_outlined
                  : Icons.auto_stories_outlined,
              size: 40,
              color: AppColors.hint,
            ),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No books match these filters'
                  : 'Nothing discovered yet',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              filtered
                  ? 'Try another genre or place'
                  : 'Switch the scanner to Discover and photograph a shelf',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (filtered) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
