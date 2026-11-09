import 'package:shelf_snap/features/library/models/book_model.dart';

// Which of the reader's keywords a book matches. Worked out on the phone
// and never stored, like TasteMatch, so editing keywords updates every
// book already scanned.
class KeywordMatch {
  const KeywordMatch._();

  // A keyword matches when each of its words is a whole word somewhere in
  // the title, subtitle or authors. Case and accents don't matter, so
  // "rowling" matches "J. K. Rowling" and "Brontë" matches "bronte".
  static List<String> of(List<String> keywords, BookModel book) {
    if (keywords.isEmpty) return const [];

    final bookWords = BookModel.sanitizeWords(
      [book.title, ?book.subtitle, ...book.authors].join(' '),
    ).toSet();

    return [
      for (final keyword in keywords)
        if (BookModel.sanitizeWords(keyword) case final words
            when words.isNotEmpty && words.every(bookWords.contains))
          keyword,
    ];
  }

  // The words to light up in a title or author line for these hits
  static Set<String> words(List<String> hits) => {
    for (final keyword in hits) ...BookModel.sanitizeWords(keyword),
  };
}
