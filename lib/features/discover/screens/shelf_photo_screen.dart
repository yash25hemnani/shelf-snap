import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/features/discover/models/discovered_book_model.dart';
import 'package:shelf_snap/features/discover/models/shelf_photo_model.dart';
import 'package:shelf_snap/features/discover/screens/discovered_book_screen.dart';
import 'package:shelf_snap/features/discover/widgets/shelf_photo_view.dart';

// A shelf photo full screen, pinch to zoom. Tapping an outline opens that
// book. Opened from a book page, that book is [highlight] and tapping it
// goes back.
class ShelfPhotoScreen extends StatelessWidget {
  final ShelfPhotoModel photo;
  final String? highlight;
  final Set<String> great;
  // The books still around from this scan, shown until their docs load;
  // null outlines every book on the photo
  final Map<String, DiscoveredBookModel>? books;

  const ShelfPhotoScreen({
    super.key,
    required this.photo,
    this.highlight,
    this.great = const {},
    this.books,
  });

  void _open(BuildContext context, String id) {
    if (id == highlight) {
      Navigator.pop(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DiscoveredBookScreen(readingKey: id, initial: books?[id]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final books = this.books;
    final found = books?.length ?? photo.bookIds.length;
    final outlined = photo.outlines.keys
        .where((id) => books == null || books.containsKey(id))
        .length;

    return Scaffold(
      backgroundColor: AppColors.text,
      appBar: AppBar(
        backgroundColor: AppColors.text,
        foregroundColor: AppColors.onPrimary,
        title: Text('Shelf photo, ${dayMonth(photo.takenAt)}'),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppColors.onPrimary,
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: ShelfPhotoView(
                  photo: photo,
                  highlight: highlight,
                  great: great,
                  only: books?.keys.toSet(),
                  onTapBook: (id) => _open(context, id),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                switch (outlined) {
                  0 => "Couldn't find where the books are on this photo",
                  _ when outlined == found => 'Tap an outline to open the book',
                  _ =>
                    'Outlined $outlined of $found books. Tap one to open it.',
                },
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
