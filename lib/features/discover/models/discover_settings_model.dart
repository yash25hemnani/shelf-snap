import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

// The reader's Discover setup: users/{uid}/settings/discover.
// Kept off users/{uid} because every signed-in user can read that doc,
// and the place says where the reader is right now.
class DiscoverSettingsModel {
  static const docId = 'discover';
  static const maxRecentPlaces = 5;
  static const maxPlaceLength = 60;
  static const maxKeywords = 30;
  static const maxKeywordLength = 40;

  final List<Genre> genres; // the reader's taste; empty = not set up yet
  final String? currentPlace; // stays on every scan until changed; null = none
  final List<String> recentPlaces; // newest first, for one-tap reuse
  final DateTime? updatedAt;
  // True once books saved before search existed got their search words
  final bool searchIndexed;
  // Authors, titles or words to look out for; matching books are highlighted
  final List<String> keywords;

  const DiscoverSettingsModel({
    this.genres = const [],
    this.currentPlace,
    this.recentPlaces = const [],
    this.updatedAt,
    this.searchIndexed = false,
    this.keywords = const [],
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
      searchIndexed: map['searchIndexed'] as bool? ?? false,
      keywords:
          (map['keywords'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'genres': genres.map((g) => g.name).toList(),
    'currentPlace': currentPlace,
    'recentPlaces': recentPlaces,
    'updatedAt': FieldValue.serverTimestamp(),
    'searchIndexed': searchIndexed,
    'keywords': keywords,
  };

  DiscoverSettingsModel copyWith({
    List<Genre>? genres,
    String? currentPlace,
    bool clearCurrentPlace = false,
    List<String>? recentPlaces,
    bool? searchIndexed,
    List<String>? keywords,
  }) {
    return DiscoverSettingsModel(
      genres: genres ?? this.genres,
      currentPlace: clearCurrentPlace
          ? null
          : currentPlace ?? this.currentPlace,
      recentPlaces: recentPlaces ?? this.recentPlaces,
      updatedAt: updatedAt,
      searchIndexed: searchIndexed ?? this.searchIndexed,
      keywords: keywords ?? this.keywords,
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

  // Returns this unchanged when the keyword is blank, already there
  // (any case), or the list is full
  DiscoverSettingsModel withKeyword(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty || keywords.length >= maxKeywords) return this;

    final word = trimmed.length > maxKeywordLength
        ? trimmed.substring(0, maxKeywordLength).trim()
        : trimmed;
    final lower = word.toLowerCase();
    if (keywords.any((k) => k.toLowerCase() == lower)) return this;

    return copyWith(keywords: [...keywords, word]);
  }

  DiscoverSettingsModel withoutKeyword(String word) =>
      copyWith(keywords: keywords.where((k) => k != word).toList());

  bool get hasGenres => genres.isNotEmpty;
  bool get hasPlace => currentPlace != null;
  bool get hasKeywords => keywords.isNotEmpty;
}
