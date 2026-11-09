import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf_snap/features/discover/models/shelf_photo_model.dart';

// Discover shelf photos in the app's own folder on the phone: a JPEG plus a
// JSON file with the outlines. Kept off Firestore and Storage, so photos
// cost nothing and stay private. Web has no app folder, so it keeps none.
class ShelfPhotoStore {
  static const _folder = 'shelf_photos';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/$_folder').create(recursive: true);
  }

  // Every saved photo, newest first. A photo whose JPEG is gone or whose
  // JSON can't be read is skipped.
  Future<List<ShelfPhotoModel>> _all() async {
    if (kIsWeb) return const [];

    final photos = <ShelfPhotoModel>[];
    await for (final entity in (await _dir()).list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final jpegPath = entity.path.replaceFirst(RegExp(r'\.json$'), '.jpg');
      try {
        if (!await File(jpegPath).exists()) continue;
        final map = jsonDecode(await entity.readAsString());
        photos.add(ShelfPhotoModel.fromMap(jpegPath, map));
      } catch (e) {
        debugPrint('Reading shelf photo ${entity.path} failed: $e');
      }
    }
    photos.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return photos;
  }

  // Saves [jpeg] (already upright) and its outlines. The JSON is written
  // last, so a half-saved photo is never listed.
  Future<ShelfPhotoModel> save(
    Uint8List jpeg, {
    required int width,
    required int height,
    required List<String> bookIds,
    required Map<String, Rect> outlines,
  }) async {
    if (kIsWeb) throw Exception('Shelf photos are not kept on the web');

    final takenAt = DateTime.now();
    final id = '${takenAt.millisecondsSinceEpoch}';
    final dir = await _dir();
    final photo = ShelfPhotoModel(
      id: id,
      path: '${dir.path}/$id.jpg',
      takenAt: takenAt,
      width: width,
      height: height,
      bookIds: bookIds,
      outlines: outlines,
    );

    try {
      await File(photo.path).writeAsBytes(jpeg, flush: true);
      await File(
        '${dir.path}/$id.json',
      ).writeAsString(jsonEncode(photo.toMap()), flush: true);
    } catch (e) {
      throw Exception('Could not save the shelf photo');
    }
    return photo;
  }

  // The newest photo [readingKey] was found on, or null
  Future<ShelfPhotoModel?> latestFor(String readingKey) async {
    for (final photo in await _all()) {
      if (photo.bookIds.contains(readingKey)) return photo;
    }
    return null;
  }

  // How many photos are saved and how many bytes they take
  Future<({int count, int bytes})> usage() async {
    if (kIsWeb) return (count: 0, bytes: 0);

    var count = 0;
    var bytes = 0;
    await for (final entity in (await _dir()).list()) {
      if (entity is! File) continue;
      bytes += await entity.length();
      if (entity.path.endsWith('.jpg')) count++;
    }
    return (count: count, bytes: bytes);
  }

  // Deletes every shelf photo. Discovered books are untouched.
  Future<void> clear() async {
    if (kIsWeb) return;

    try {
      final dir = await _dir();
      await dir.delete(recursive: true);
    } catch (e) {
      throw Exception('Could not clear the shelf photos');
    }
    // Image.file caches by path, so a cleared photo could still show
    PaintingBinding.instance.imageCache.clear();
  }
}
