import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

typedef _Line = ({Rect box, Set<String> words});

// Finds where each found book sits on the shelf photo, using the text the
// phone already read (OCR) before the photo went to the server. The server
// doesn't send positions, so a book is outlined around the text lines that
// hold its title or author words. Works out roughly the title area of the
// spine, not its exact edges.
class SpineOutliner {
  SpineOutliner._();

  // Too common to tell two spines apart
  static const _skipWords = {
    'the', 'and', 'of', 'an', 'to', 'in', 'for', 'on', 'with', 'by', 'at', //
    'or', 'is', 'de', 'la', 'le', 'el', 'les', 'der', 'die', 'das', 'und',
  };

  // A line needs this many matching letters to count, so a stray two-letter
  // word can't outline a book on its own
  static const _minScore = 4;

  static Set<String> _words(String text) => BookModel.sanitizeWords(
    text,
  ).where((w) => !_skipWords.contains(w)).toSet();

  // The best line for [book], grown to take in matching lines right next to
  // it, so a title split over two lines on one spine is outlined whole
  static Rect? _find(List<_Line> lines, BookModel book) {
    final titleWords = _words(
      [
        if (book.title != BookModel.unknownTitle) book.title,
        ?book.subtitle,
      ].join(' '),
    );
    final authorWords = _words(book.authors.join(' '));

    // Title letters count double: one author can have several spines on a
    // shelf, but a title is usually on one
    final matches = <({Rect box, int score})>[];
    for (final line in lines) {
      var score = 0;
      for (final word in line.words) {
        if (titleWords.contains(word)) {
          score += word.length * 2;
        } else if (authorWords.contains(word)) {
          score += word.length;
        }
      }
      if (score >= _minScore) matches.add((box: line.box, score: score));
    }
    if (matches.isEmpty) return null;

    matches.sort((a, b) => b.score.compareTo(a.score));
    var outline = matches.first.box;
    // Half a line's thickness: close enough for the next line on the same
    // spine, too far for the text on the spine beside it
    final reach = outline.shortestSide / 2;
    final rest = [for (final m in matches.skip(1)) m.box];

    var grew = true;
    while (grew) {
      grew = false;
      for (var i = rest.length - 1; i >= 0; i--) {
        if (outline.inflate(reach).overlaps(rest[i])) {
          outline = outline.expandToInclude(rest.removeAt(i));
          grew = true;
        }
      }
    }

    // A little room around the text so the outline doesn't cut through it
    return outline.inflate(outline.shortestSide / 4);
  }

  // readingKey -> outline as fractions (0–1) of [imageSize], the upright
  // size of the photo the OCR ran on. Books that can't be found are left out.
  static Map<String, Rect> outline(
    List<TextBlock> blocks,
    List<DiscoveredBookModel> books,
    Size imageSize,
  ) {
    if (imageSize.isEmpty) return const {};

    final lines = <_Line>[
      for (final block in blocks)
        for (final line in block.lines)
          (box: line.boundingBox, words: _words(line.text)),
    ];
    final bounds = Offset.zero & imageSize;

    final outlines = <String, Rect>{};
    for (final item in books) {
      final box = _find(lines, item.book)?.intersect(bounds);
      if (box == null || box.isEmpty) continue;

      outlines[item.id] = Rect.fromLTRB(
        box.left / imageSize.width,
        box.top / imageSize.height,
        box.right / imageSize.width,
        box.bottom / imageSize.height,
      );
    }
    return outlines;
  }
}
