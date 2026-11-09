import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

// The reader's Discover setup: users/{uid}/settings/discover.
// Kept off users/{uid} because every signed-in user can read that doc,
// and the place says where the reader is right now.
class DiscoverSettingsModel {
  static const docId = 'discover';
  static const maxRecentPlaces = 5;
  static const maxPlaceLength = 60;

  final List<Genre> genres; // the reader's taste; empty = not set up yet
  final String? currentPlace; // stays on every scan until changed; null = none
  final List<String> recentPlaces; // newest first, for one-tap reuse
  final DateTime? updatedAt;

  const DiscoverSettingsModel({
    this.genres = const [],
    this.currentPlace,
    this.recentPlaces = const [],
    this.updatedAt,
  });

  // One fixed doc, so there's no id to pass in. A missing doc reads as empty.
  factory DiscoverSettingsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DiscoverSettingsModel();

    return DiscoverSettingsModel(
      genres: [
        for (final name
            in (map['genres'] as List?)?.whereType<String>() ??
                const <String>[])
          ?Genre.values.asNameMap()[name],
      ],
      currentPlace: map['currentPlace'] as String?,
      recentPlaces: (map['recentPlaces'] as List?)?.cast<String>() ?? const [],
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'genres': genres.map((g) => g.name).toList(),
    'currentPlace': currentPlace,
    'recentPlaces': recentPlaces,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  DiscoverSettingsModel copyWith({
    List<Genre>? genres,
    String? currentPlace,
    bool clearCurrentPlace = false,
    List<String>? recentPlaces,
  }) {
    return DiscoverSettingsModel(
      genres: genres ?? this.genres,
      currentPlace: clearCurrentPlace
          ? null
          : currentPlace ?? this.currentPlace,
      recentPlaces: recentPlaces ?? this.recentPlaces,
      updatedAt: updatedAt,
    );
  }

  // Sets the place for the next scans and moves it to the front of the
  // recent list. Blank or null clears it; the recent list stays.
  DiscoverSettingsModel withPlace(String? place) {
    final trimmed = place?.trim() ?? '';
    if (trimmed.isEmpty) return copyWith(clearCurrentPlace: true);

    final name = trimmed.length > maxPlaceLength
        ? trimmed.substring(0, maxPlaceLength)
        : trimmed;
    final lower = name.toLowerCase();
    final recent = [
      name,
      ...recentPlaces.where((p) => p.toLowerCase() != lower),
    ].take(maxRecentPlaces).toList();

    return copyWith(currentPlace: name, recentPlaces: recent);
  }

  bool get hasGenres => genres.isNotEmpty;
  bool get hasPlace => currentPlace != null;
}
