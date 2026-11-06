import 'package:flutter/foundation.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

// Which field the typed text searches. The name is the backend's parameter.
enum SearchField { title, author }

// One submitted search. Value equality so the results provider reuses the
// same request when nothing changed.
@immutable
class SearchQuery {
  // The backend rejects shorter terms with a 400
  static const minTextLength = 2;
  // Each genre is a separate Open Library call, so keep it small
  static const maxGenres = 3;

  final String text;
  final SearchField field;
  final Set<Genre> genres;

  const SearchQuery({
    this.text = '',
    this.field = SearchField.title,
    this.genres = const {},
  });

  String get trimmedText => text.trim();

  bool get hasText => trimmedText.length >= minTextLength;

  bool get isEmpty => !hasText && genres.isEmpty;

  SearchQuery copyWith({
    String? text,
    SearchField? field,
    Set<Genre>? genres,
  }) {
    return SearchQuery(
      text: text ?? this.text,
      field: field ?? this.field,
      genres: genres ?? this.genres,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.trimmedText == trimmedText &&
      other.field == field &&
      setEquals(other.genres, genres);

  @override
  int get hashCode =>
      Object.hash(trimmedText, field, Object.hashAllUnordered(genres));
}
