import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';

// Text with the given words in bold green. Words are compared the way
// search compares them (lowercase, no accents), so "Bronte" lights up
// "Brontë". With no words it's a plain Text.
class HighlightedText extends StatelessWidget {
  // Runs of letters and numbers, and the gaps between them
  static final _pieces = RegExp(
    r'[\p{L}\p{M}\p{N}]+|[^\p{L}\p{M}\p{N}]+',
    unicode: true,
  );

  final String text;
  final Set<String> words; // already sanitized
  final TextStyle? style;
  final int? maxLines;

  const HighlightedText(
    this.text, {
    super.key,
    this.words = const {},
    this.style,
    this.maxLines,
  });

  bool _isHit(String piece) {
    final sanitized = BookModel.sanitizeWords(piece);
    return sanitized.length == 1 && words.contains(sanitized.first);
  }

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final hitStyle = (style ?? const TextStyle()).copyWith(
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w700,
    );

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final match in _pieces.allMatches(text))
            if (match[0]! case final piece)
              TextSpan(text: piece, style: _isHit(piece) ? hitStyle : null),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
