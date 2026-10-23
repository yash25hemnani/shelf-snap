import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/forms/add_book_form.dart';

class AddBookSheet extends StatelessWidget {
  final String libraryId;
  const AddBookSheet({super.key, required this.libraryId});

  static Future<void> show(BuildContext context, {required String libraryId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddBookSheet(libraryId: libraryId),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bottom inset lifts the form above the keyboard
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AddBookForm(libraryId: libraryId),
    );
  }
}
