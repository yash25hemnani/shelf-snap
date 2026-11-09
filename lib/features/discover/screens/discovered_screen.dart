import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/taste_match.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';
import 'package:shelf_snap/features/discover/screens/discovered_book_screen.dart';
import 'package:shelf_snap/features/discover/sheets/discover_genres_sheet.dart';
import 'package:shelf_snap/features/discover/sheets/place_sheet.dart';
import 'package:shelf_snap/features/discover/widgets/discovered_book_tile.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/sheets/genre_picker_sheet.dart';

// Every book found in Discover mode, a page at a time, grouped by how well
// it matches your genres, with search and genre and place filters on top.
// Long-press a book to select several and remove them or add a place.
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

  void _loadMore(WidgetRef ref) {
    ref.read(discoveredLimitProvider.notifier).state += discoveredPageSize;
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

  // A new Set each time, so Riverpod sees the change
  void _toggleSelected(WidgetRef ref, DiscoveredBookModel item) {
    final notifier = ref.read(discoveredSelectionProvider.notifier);
    final next = {...notifier.state};
    if (!next.remove(item.id)) next.add(item.id);
    notifier.state = next;
  }

  void _clearSelection(WidgetRef ref) {
    ref.read(discoveredSelectionProvider.notifier).state = const {};
  }

  static String _bookCount(int count) => count == 1 ? '1 book' : '$count books';

  // Not awaited, like a single remove, so it still works offline
  Future<void> _removeSelected(
    BuildContext context,
    WidgetRef ref,
    Set<String> ids,
  ) async {
    final count = _bookCount(ids.length);
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove $count?',
      message: 'They will be removed from Discovered.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    _clearSelection(ref);
    unawaited(
      ref.read(discoverRepositoryProvider).deleteBooks(userId, ids).catchError((
        Object e,
      ) {
        debugPrint('deleteBooks failed: $e');
        messenger.showError("Couldn't remove these books");
      }),
    );
    messenger.showMessage('Removed $count');
  }

  // Tags the selected books with a place and adds it to the recent places,
  // so it shows up as a filter. The place for new scans stays as it was.
  Future<void> _addPlaceToSelected(
    BuildContext context,
    WidgetRef ref,
    DiscoverSettingsModel settings,
    List<DiscoveredBookModel> books,
    Set<String> ids,
  ) async {
    final place = await PlaceSheet.show(
      context,
      settings: settings,
      pickOnly: true,
    );
    if (place == null || !context.mounted) return;
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (userId == null) return;

    // Only books still in the list (an update on a removed one fails the
    // batch), and not ones already holding the most places
    final keys = [
      for (final book in books)
        if (ids.contains(book.id) &&
            (book.places.contains(place) ||
                book.places.length < DiscoveredBookModel.maxPlaces))
          book.id,
    ];
    final messenger = ScaffoldMessenger.of(context);
    if (keys.isEmpty) {
      messenger.showError('These books already have too many places');
      return;
    }

    final repository = ref.read(discoverRepositoryProvider);
    _clearSelection(ref);
    unawaited(
      repository.addPlace(userId, keys, place).catchError((Object e) {
        debugPrint('addPlace failed: $e');
        messenger.showError("Couldn't add the place");
      }),
    );
    unawaited(
      repository
          .saveSettings(
            userId,
            settings.copyWith(
              recentPlaces: settings.withPlace(place).recentPlaces,
            ),
          )
          .catchError((Object e) => debugPrint('saveSettings failed: $e')),
    );
    messenger.showMessage('Added $place to ${_bookCount(keys.length)}');
  }

  void _search(WidgetRef ref, String text) {
    ref.read(discoveredSearchProvider.notifier).state = text;
    if (text.trim().isNotEmpty) _indexOldBooks(ref);
  }

  // Books saved before search existed have no search words yet. The first
  // search fills them in, and results show up as each batch lands.
  // Waits for the settings to load, so the flag isn't read from defaults.
  void _indexOldBooks(WidgetRef ref) {
    final settings = ref.read(discoverSettingsProvider);
    if (!settings.hasValue || settings.requireValue.searchIndexed) return;
    final started = ref.read(discoveredIndexStartedProvider.notifier);
    if (started.state) return;
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (userId == null) return;

    // Stays true on failure too; the next app start tries again
    started.state = true;
    unawaited(
      ref
          .read(discoverRepositoryProvider)
          .indexForSearch(userId)
          .catchError((Object e) => debugPrint('indexForSearch failed: $e')),
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
    final limit = ref.watch(discoveredLimitProvider);
    final search = ref.watch(discoveredSearchProvider);
    final selected = ref.watch(discoveredSelectionProvider);
    final selecting = selected.isNotEmpty;
    final filtered = genre != null || place != null;

    // Recent places, plus the filtered one if it has dropped off the list
    final places = [
      ...settings.recentPlaces,
      if (place != null && !settings.recentPlaces.contains(place)) place,
    ];

    // One letter is too short to search, so the full list stays
    final searching = BookModel.sanitizeWords(search).isNotEmpty;
    final searchAsync = ref.watch(discoveredSearchResultsProvider);
    final listAsync = searching ? searchAsync : booksAsync;
    final books = listAsync.valueOrNull ?? const <DiscoveredBookModel>[];
    // A full page back means there may be more. Filters and extra search
    // words are checked after the limit, so this can miss a few.
    final canLoadMore = books.length >= limit;

    final normalBar = AppBar(
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
        const SizedBox(width: 4),
      ],
    );

    final selectionBar = AppBar(
      leading: IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close_rounded),
        onPressed: () => _clearSelection(ref),
      ),
      title: Text('${selected.length} selected'),
      titleTextStyle: textTheme.titleMedium,
      titleSpacing: 0,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      actions: [
        IconButton(
          tooltip: 'Select all',
          icon: const Icon(Icons.select_all_rounded),
          onPressed: () =>
              ref.read(discoveredSelectionProvider.notifier).state = {
                ...selected,
                for (final b in books) b.id,
              },
        ),
        IconButton(
          tooltip: 'Add a place',
          icon: const Icon(Icons.add_location_alt_outlined),
          onPressed: () =>
              _addPlaceToSelected(context, ref, settings, books, selected),
        ),
        IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _removeSelected(context, ref, selected),
        ),
        const SizedBox(width: 4),
      ],
    );

    // Back leaves selection first, then the page
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection(ref);
      },
      child: Scaffold(
        appBar: selecting ? selectionBar : normalBar,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SearchField(onChanged: (v) => _search(ref, v)),
            ),
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
              child: listAsync.when(
                // Keeps the list on screen while "Load more" or a new
                // search word re-queries
                skipLoadingOnReload: true,
                data: (_) {
                  if (books.isEmpty && searching) {
                    return _NoSearchMatch(
                      query: search.trim(),
                      filtered: filtered,
                      onClear: () => _clearFilters(ref),
                    );
                  }
                  if (books.isEmpty) {
                    return _Empty(
                      filtered: filtered,
                      onClear: () => _clearFilters(ref),
                    );
                  }
                  return _BookList(
                    books: books,
                    settings: settings,
                    selected: selected,
                    canLoadMore: canLoadMore,
                    onOpen: (item) => _open(context, item),
                    onToggle: (item) => _toggleSelected(ref, item),
                    onRemove: (item) =>
                        DiscoveredBookScreen.confirmRemove(context, ref, item),
                    onPickGenres: () =>
                        showDiscoverGenresSheet(context, ref, settings),
                    onLoadMore: () => _loadMore(ref),
                  );
                },
                error: (e, _) {
                  debugPrint(
                    '${searching ? 'searchDiscovered' : 'watchDiscovered'} '
                    'failed: $e',
                  );
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
      ),
    );
  }
}

// Owns its controller so the clear button can empty the field. Reports the
// text a moment after typing stops, so each key press isn't a Firestore query.
class _SearchField extends StatefulWidget {
  static const _debounce = Duration(milliseconds: 300);

  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();
  Timer? _timer;

  void _changed(String text) {
    _timer?.cancel();
    _timer = Timer(_SearchField._debounce, () => widget.onChanged(text));
  }

  // The keyboard's search key and the clear button don't wait
  void _now(String text) {
    _timer?.cancel();
    widget.onChanged(text);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: _changed,
      onSubmitted: _now,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: 'Search title or author',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _controller.clear();
                    _now('');
                  },
                ),
        ),
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
  final Set<String> selected;
  final bool canLoadMore;
  final ValueChanged<DiscoveredBookModel> onOpen;
  final ValueChanged<DiscoveredBookModel> onToggle;
  final Future<bool> Function(DiscoveredBookModel) onRemove;
  final VoidCallback onPickGenres;
  final VoidCallback onLoadMore;

  const _BookList({
    required this.books,
    required this.settings,
    required this.selected,
    required this.canLoadMore,
    required this.onOpen,
    required this.onToggle,
    required this.onRemove,
    required this.onPickGenres,
    required this.onLoadMore,
  });

  // Firestore drops a deleted book from the stream straight away, even
  // offline, so the swiped row leaves the list as Dismissible needs.
  // While selecting, a tap picks the book and swiping is off.
  Widget _tile(DiscoveredBookModel item) {
    final selecting = selected.isNotEmpty;
    return DiscoveredBookTile(
      item: item,
      selected: selected.contains(item.id),
      onTap: () => selecting ? onToggle(item) : onOpen(item),
      onLongPress: () => onToggle(item),
      onRemove: selecting ? null : () => onRemove(item),
    );
  }

  Widget _loadMoreButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Center(
        child: OutlinedButton(
          onPressed: onLoadMore,
          child: const Text('Load more'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!settings.hasGenres) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _PickGenresCard(onTap: onPickGenres),
          for (final item in books) _tile(item),
          if (canLoadMore) _loadMoreButton(),
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
            for (final item in items) _tile(item),
          ],
        if (canLoadMore) _loadMoreButton(),
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

// Search covers every discovered book, so the only way to widen it is
// clearing the genre and place filters
class _NoSearchMatch extends StatelessWidget {
  final String query;
  final bool filtered;
  final VoidCallback onClear;

  const _NoSearchMatch({
    required this.query,
    required this.filtered,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppColors.hint,
            ),
            const SizedBox(height: 12),
            Text(
              'No books match "$query"',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              filtered
                  ? 'Only books with this genre or place are searched'
                  : 'Search looks at the start of words in titles and authors',
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
