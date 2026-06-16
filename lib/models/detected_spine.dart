import 'scanned_text_block.dart';

/// A group of ScannedTextBlocks believed to belong to the same book spine.
class DetectedSpine {
  final List<ScannedTextBlock> textBlocks;

  DetectedSpine({required this.textBlocks});

  // ─── X-range (used for vertical spine clustering) ─────
  double get left => textBlocks
      .map((b) => b.boundingBox.left)
      .reduce((a, b) => a < b ? a : b);

  double get right => textBlocks
      .map((b) => b.boundingBox.right)
      .reduce((a, b) => a > b ? a : b);

  // ─── Y-range (used for horizontal stack clustering) ───
  double get top => textBlocks
      .map((b) => b.boundingBox.top)
      .reduce((a, b) => a < b ? a : b);

  double get bottom => textBlocks
      .map((b) => b.boundingBox.bottom)
      .reduce((a, b) => a > b ? a : b);

  /// All text on this spine, ordered top-to-bottom (vertical)
  /// or left-to-right (horizontal) by bounding box position.
  String get fullText {
    final sorted = [...textBlocks]
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    return sorted.map((b) => b.text).join(' ');
  }

  @override
  String toString() => 'DetectedSpine("$fullText", x: $left-$right, y: $top-$bottom)';
}