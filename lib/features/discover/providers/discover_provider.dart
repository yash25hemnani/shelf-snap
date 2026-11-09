import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/repositories/discover_repository.dart';
import 'package:shelf_snap/features/discover/services/discover_service.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

final discoverRepositoryProvider = Provider((ref) => DiscoverRepository());

final discoverServiceProvider = Provider((ref) => DiscoverService());

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

// The Discovered list, most recently seen first. Re-queries when a filter
// changes; the repository caps it at 50 books.
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
