import 'package:shelf_snap/features/library/models/genre.dart';

// How well a book's genres fit the reader's picked genres. Worked out on
// the phone and never stored, so changing your genres re-sorts every book
// you've already scanned. Declared in sort order, best first; an unknown
// genre sits above a known miss, since it might still be a match.
enum TasteMatch {
  strong('Great match', 'Great matches'),
  partial('Good match', 'Good matches'),
  unknown('Genre unknown', 'Genre unknown'),
  none('Not your genres', 'Other genres');

  final String label; // on one book
  final String heading; // above a group of books

  const TasteMatch(this.label, this.heading);

  // Null when the reader hasn't picked any genres, so there's nothing to
  // compare against. Strong = every genre the book has is one you picked.
  static TasteMatch? of(List<Genre> taste, List<Genre> bookGenres) {
    if (taste.isEmpty) return null;
    if (bookGenres.isEmpty) return TasteMatch.unknown;

    final hits = bookGenres.where(taste.contains).length;
    if (hits == 0) return TasteMatch.none;
    return hits == bookGenres.length ? TasteMatch.strong : TasteMatch.partial;
  }
}
