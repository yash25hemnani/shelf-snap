import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:string_similarity/string_similarity.dart';
import '../models/scanned_text_block.dart';
import '../models/detected_spine.dart';

enum TextOrientation { vertical, horizontal }

/// Takes raw OCR output from ML Kit and groups it into individual book spines.
///
/// Handles two physical shelf layouts:
/// - Vertical spines (books standing upright) — text is rotated, bounding
///   boxes are tall-and-narrow → clustered by X-range overlap
/// - Horizontal stacks (books lying flat) — text is horizontal, bounding
///   boxes are wide-and-short → clustered by Y-range overlap
///
/// IMPORTANT: a single real spine can contain BOTH orientations at once —
/// e.g. a vertically-printed title running most of the spine's height, with
/// a short horizontally-printed author name or imprint near the bottom.
/// Because vertical and horizontal blocks are clustered in separate passes
/// below, that case would otherwise split one physical book into two
/// "spines" forever. _mergeAcrossOrientation() reconciles that after the
/// initial clustering, before deduplication.
class SpineDetectionService {
  final double overlapTolerance;
  final double deduplicationThreshold;

  SpineDetectionService({
    this.overlapTolerance       = 5,
    this.deduplicationThreshold = 0.8,
  });

  // ─── Public entry points ──────────────────────────────

  /// Full pipeline from raw ML Kit output.
  /// Use this when you want to pass ALL OCR blocks (no pre-filtering).
  List<DetectedSpine> detectSpines(RecognizedText recognizedText) {
    final blocks = recognizedText.blocks
        .map((b) => ScannedTextBlock(
      text:        b.text,
      boundingBox: b.boundingBox,
    ))
        .toList();
    return _cluster(blocks);
  }

  /// Pipeline from a pre-filtered block list.
  /// Use this when blocks have already been cropped to a guide rect
  /// (e.g. from scanner_screen._guideRectInImageCoords filtering).
  List<DetectedSpine> detectSpinesFromBlocks(List<TextBlock> blocks) {
    final scannedBlocks = blocks
        .map((b) => ScannedTextBlock(
      text:        b.text,
      boundingBox: b.boundingBox,
    ))
        .toList();
    return _cluster(scannedBlocks);
  }

  // ─── Core clustering pipeline ─────────────────────────

  /// Shared implementation: orient → cluster (per orientation) →
  /// merge across orientation → deduplicate.
  List<DetectedSpine> _cluster(List<ScannedTextBlock> textBlocks) {
    final vertical   = textBlocks.where((b) => _orientation(b) == TextOrientation.vertical).toList();
    final horizontal = textBlocks.where((b) => _orientation(b) == TextOrientation.horizontal).toList();

    // Cluster each orientation independently first — this is what correctly
    // separates side-by-side spines that happen to share the same
    // orientation (e.g. two vertical titles next to each other).
    final orientedSpines = [
      ..._groupByXOverlap(vertical),
      ..._groupByYOverlap(horizontal),
    ];

    // Then reconcile across the orientation boundary — this is what catches
    // a single spine whose title (vertical) and author/imprint (horizontal)
    // were clustered separately purely because of the orientation pre-split,
    // even though their X-ranges clearly overlap and they're the same book.
    final mergedSpines = _mergeAcrossOrientation(orientedSpines);

    return _deduplicateSpines(mergedSpines);
  }

  // ─── Orientation detection ────────────────────────────

  TextOrientation _orientation(ScannedTextBlock block) {
    return block.boundingBox.width > block.boundingBox.height
        ? TextOrientation.horizontal
        : TextOrientation.vertical;
  }

  // ─── Clustering — vertical spines (X-axis) ────────────

  List<DetectedSpine> _groupByXOverlap(List<ScannedTextBlock> blocks) {
    final List<DetectedSpine> spines = [];

    for (final block in blocks) {
      bool matched = false;
      for (final spine in spines) {
        if (_rangesOverlap(
          block.boundingBox.left, block.boundingBox.right,
          spine.left,             spine.right,
        )) {
          spine.textBlocks.add(block);
          matched = true;
          break;
        }
      }
      if (!matched) spines.add(DetectedSpine(textBlocks: [block]));
    }

    return spines;
  }

  // ─── Clustering — horizontal stacks (Y-axis) ──────────

  List<DetectedSpine> _groupByYOverlap(List<ScannedTextBlock> blocks) {
    final List<DetectedSpine> spines = [];

    for (final block in blocks) {
      bool matched = false;
      for (final spine in spines) {
        if (_rangesOverlap(
          block.boundingBox.top, block.boundingBox.bottom,
          spine.top,             spine.bottom,
        )) {
          spine.textBlocks.add(block);
          matched = true;
          break;
        }
      }
      if (!matched) spines.add(DetectedSpine(textBlocks: [block]));
    }

    return spines;
  }

  // ─── Merging — reconcile across orientation split ─────

  /// After vertical and horizontal blocks have each been clustered
  /// independently, this pass merges any two spines whose X-ranges overlap
  /// — regardless of which orientation pool they came from.
  ///
  /// Why this is needed: a real spine like "The Gulf: The Making of an
  /// American Sea" by Jack E. Davis can have its title printed vertically
  /// (tall/narrow bounding box → vertical pool) and the author name printed
  /// horizontally near the bottom (wide/short bounding box → horizontal
  /// pool). Without this pass, _groupByXOverlap and _groupByYOverlap never
  /// compare blocks across pools, so these two fragments stay permanently
  /// separate — producing two weak, unmatchable "spines" instead of one
  /// strong, searchable one.
  ///
  /// Uses the same overlapTolerance as the rest of the class, so it's
  /// conservative: it only merges on genuine X-range overlap, not mere
  /// proximity, to avoid incorrectly fusing two distinct adjacent spines.
  List<DetectedSpine> _mergeAcrossOrientation(List<DetectedSpine> spines) {
    final List<DetectedSpine> merged = [];

    for (final spine in spines) {
      DetectedSpine? target;
      for (final existing in merged) {
        if (_rangesOverlap(spine.left, spine.right, existing.left, existing.right)) {
          target = existing;
          break;
        }
      }

      if (target == null) {
        merged.add(spine);
      } else {
        final index = merged.indexOf(target);
        merged[index] = DetectedSpine(
          textBlocks: [...target.textBlocks, ...spine.textBlocks],
        );
      }
    }

    return merged;
  }

  // ─── Shared overlap check ─────────────────────────────

  bool _rangesOverlap(double a1, double a2, double b1, double b2) {
    return a1 <= b2 + overlapTolerance && b1 <= a2 + overlapTolerance;
  }

  // ─── Deduplication ────────────────────────────────────

  List<DetectedSpine> _deduplicateSpines(List<DetectedSpine> spines) {
    final List<DetectedSpine> deduplicated = [];

    for (final spine in spines) {
      bool isDuplicate = false;

      for (int i = 0; i < deduplicated.length; i++) {
        final score = StringSimilarity.compareTwoStrings(
          spine.fullText.toLowerCase(),
          deduplicated[i].fullText.toLowerCase(),
        );
        if (score >= deduplicationThreshold) {
          if (spine.textBlocks.length > deduplicated[i].textBlocks.length) {
            deduplicated[i] = spine;
          }
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) deduplicated.add(spine);
    }

    return deduplicated;
  }
}