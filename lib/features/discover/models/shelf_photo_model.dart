import 'dart:ui';

// One Discover shelf photo saved on this phone, with an outline for each
// book that could be found on it. Never uploaded, so it only exists on the
// phone that took it, until "Clear shelf photos" deletes it.
class ShelfPhotoModel {
  final String id; // file name without the extension
  final String path; // the JPEG
  final DateTime takenAt;
  final int width; // pixels of the saved JPEG
  final int height;
  final List<String> bookIds; // readingKeys of every book found
  // readingKey -> outline as fractions (0–1) of the photo's width and
  // height. Books whose title couldn't be found on the photo are missing.
  final Map<String, Rect> outlines;

  const ShelfPhotoModel({
    required this.id,
    required this.path,
    required this.takenAt,
    required this.width,
    required this.height,
    this.bookIds = const [],
    this.outlines = const {},
  });

  double get aspectRatio => height == 0 ? 1 : width / height;

  // Saved next to the JPEG as JSON. [path] comes from the file's location,
  // since the app folder can move between installs.
  factory ShelfPhotoModel.fromMap(String path, Map<String, dynamic> map) {
    final outlines = <String, Rect>{};
    final rawOutlines = map['outlines'];
    if (rawOutlines is Map) {
      for (final MapEntry(:key, :value) in rawOutlines.entries) {
        if (key is! String || value is! List || value.length != 4) continue;
        final [l, t, r, b] = [for (final v in value) (v as num).toDouble()];
        outlines[key] = Rect.fromLTRB(l, t, r, b);
      }
    }

    return ShelfPhotoModel(
      id: map['id'] as String,
      path: path,
      takenAt: DateTime.fromMillisecondsSinceEpoch(
        (map['takenAt'] as num).toInt(),
      ),
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      bookIds:
          (map['bookIds'] as List?)?.whereType<String>().toList() ?? const [],
      outlines: outlines,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'takenAt': takenAt.millisecondsSinceEpoch,
    'width': width,
    'height': height,
    'bookIds': bookIds,
    'outlines': {
      for (final MapEntry(:key, :value) in outlines.entries)
        key: [value.left, value.top, value.right, value.bottom],
    },
  };
}
