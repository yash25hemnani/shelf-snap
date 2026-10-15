import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/forms/add_book_form.dart';

class AddBookDialog extends StatelessWidget {
  final String libraryId;
  const AddBookDialog({super.key, required this.libraryId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AddBookForm(libraryId: libraryId),
      ),
    );
  }
}
