import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/shelf_photo_model.dart';
import 'package:shelf_snap/features/discover/repositories/discover_repository.dart';
import 'package:shelf_snap/features/discover/services/discover_service.dart';
import 'package:shelf_snap/features/discover/services/shelf_photo_store.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

final discoverRepositoryProvider = Provider((ref) => DiscoverRepository());

final discoverServiceProvider = Provider((ref) => DiscoverService());

final shelfPhotoStoreProvider = Provider((ref) => ShelfPhotoStore());

// The newest shelf photo on this phone that a book was found on; null when
// there's none (another phone, cleared, or the web). Invalidated after
// "Clear shelf photos".
final shelfPhotoForBookProvider = FutureProvider.autoDispose
    .family<ShelfPhotoModel?, String>(
      (ref, readingKey) =>
          ref.watch(shelfPhotoStoreProvider).latestFor(readingKey),
    );

// The reader's genres and place. Empty settings when signed out or not
// set up yet, so the scanner and sheets never have to handle null.
final discoverSettingsProvider =
    StreamProvider.autoDispose<DiscoverSettingsModel>((ref) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(const DiscoverSettingsModel());

      return ref.watch(discoverRepositoryProvider).watchSettings(userId);
    });

// Filters on the Discovered list; null = all
final discoveredGenreFilterProvider = StateProvider.autoDispose<Genre?>(
  (ref) => null,
);
final discoveredPlaceFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

// Search text on the Discovered list, set a moment after typing stops
final discoveredSearchProvider = StateProvider.autoDispose<String>((ref) => '');

// Books per "Load more" on the Discovered list
const discoveredPageSize = 50;

// How many books the Discovered list (or the search) loads. Watching the
// filters and the search puts it back to one page whenever they change.
final discoveredLimitProvider = StateProvider.autoDispose<int>((ref) {
  ref.watch(discoveredGenreFilterProvider);
  ref.watch(discoveredPlaceFilterProvider);
  ref.watch(discoveredSearchProvider);
  return discoveredPageSize;
});

// Ids of the books picked for a bulk action; empty = not selecting.
// Cleared when a filter or the search changes so hidden books can't stay
// selected.
final discoveredSelectionProvider = StateProvider.autoDispose<Set<String>>((
  ref,
) {
  ref.watch(discoveredGenreFilterProvider);
  ref.watch(discoveredPlaceFilterProvider);
  ref.watch(discoveredSearchProvider);
  return const {};
});

// Set once the fill-in for old books has started this session, so typing
// more doesn't start it again. Not autoDispose, so it outlives the screen.
final discoveredIndexStartedProvider = StateProvider<bool>((ref) => false);

// Every discovered book matching each word of the search, most recently
// seen first; empty when the search is empty. Firestore takes one
// arrayContains, so the longest word (fewest matches) goes to Firestore
// and the other words and the genre and place filters are checked here.
final discoveredSearchResultsProvider =
    StreamProvider.autoDispose<List<DiscoveredBookModel>>((ref) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      final words = BookModel.sanitizeWords(
        ref.watch(discoveredSearchProvider),
      );
      if (userId == null || words.isEmpty) return Stream.value(const []);
      words.sort((a, b) => b.length.compareTo(a.length));

      final genre = ref.watch(discoveredGenreFilterProvider);
      final place = ref.watch(discoveredPlaceFilterProvider);

      return ref
          .watch(discoverRepositoryProvider)
          .searchDiscovered(
            userId,
            words.first,
            limit: ref.watch(discoveredLimitProvider),
          )
          .map(
            (books) => books.where((item) {
              final tokens = item.book.searchTokens.toSet();
              return words.every(tokens.contains) &&
                  (genre == null || item.genres.contains(genre)) &&
                  (place == null || item.places.contains(place));
            }).toList(),
          );
    });

// The Discovered list, most recently seen first. Re-queries when a filter
// or the limit changes.
final discoveredBooksProvider =
    StreamProvider.autoDispose<List<DiscoveredBookModel>>((ref) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(const []);

      return ref
          .watch(discoverRepositoryProvider)
          .watchDiscovered(
            userId,
            genre: ref.watch(discoveredGenreFilterProvider),
            place: ref.watch(discoveredPlaceFilterProvider),
            limit: ref.watch(discoveredLimitProvider),
          );
    });

// One discovered book, for the detail page; null when it was removed
final discoveredBookProvider = StreamProvider.autoDispose
    .family<DiscoveredBookModel?, String>((ref, readingKey) {
      final userId = ref.watch(currentUidProvider).valueOrNull;
      if (userId == null) return Stream.value(null);

      return ref
          .watch(discoverRepositoryProvider)
          .watchBook(userId, readingKey);
    });
