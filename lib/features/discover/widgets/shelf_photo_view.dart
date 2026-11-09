import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/discover/models/shelf_photo_model.dart';

// A shelf photo at its own shape with the found books outlined on top.
// Great matches are outlined in gold, the rest in white. With [highlight]
// set, that book is filled in and the others fade back.
class ShelfPhotoView extends StatelessWidget {
  final ShelfPhotoModel photo;
  final String? highlight;
  final Set<String> great;
  // Only these books are outlined, e.g. leaving out ones removed since the
  // scan; null outlines every book on the photo
  final Set<String>? only;
  // Null makes the outlines plain, for small previews
  final ValueChanged<String>? onTapBook;

  const ShelfPhotoView({
    super.key,
    required this.photo,
    this.highlight,
    this.great = const {},
    this.only,
    this.onTapBook,
  });

  BoxDecoration _decoration(String id) {
    final picked = id == highlight;
    final faded = highlight != null && !picked;
    final color = picked || great.contains(id)
        ? AppColors.secondary
        : AppColors.onPrimary;

    return BoxDecoration(
      color: picked ? AppColors.secondary.withValues(alpha: 0.25) : null,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: faded ? color.withValues(alpha: 0.5) : color,
        width: picked ? 3 : 2,
      ),
      // A dark edge keeps a white outline visible on light spines
      boxShadow: [
        BoxShadow(color: AppColors.text.withValues(alpha: 0.5), blurRadius: 2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final onTapBook = this.onTapBook;
    final only = this.only;
    final outlines = [
      for (final MapEntry(:key, :value) in photo.outlines.entries)
        if (only == null || only.contains(key)) (id: key, rect: value),
    ];
    // The picked book last, so it's drawn on top of any neighbour it overlaps
    outlines.sort(
      (a, b) => (a.id == highlight ? 1 : 0) - (b.id == highlight ? 1 : 0),
    );

    return AspectRatio(
      aspectRatio: photo.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          // Decode no bigger than shown, so small previews stay light
          final cacheWidth =
              (size.width * MediaQuery.devicePixelRatioOf(context)).round();

          return Stack(
            children: [
              Positioned.fill(
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.fill,
                  cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: Center(
                      child: Icon(
                        Icons.hide_image_outlined,
                        color: AppColors.hint,
                      ),
                    ),
                  ),
                ),
              ),
              for (final (:id, :rect) in outlines)
                Positioned.fromRect(
                  rect: Rect.fromLTRB(
                    rect.left * size.width,
                    rect.top * size.height,
                    rect.right * size.width,
                    rect.bottom * size.height,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapBook == null ? null : () => onTapBook(id),
                    child: DecoratedBox(decoration: _decoration(id)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
