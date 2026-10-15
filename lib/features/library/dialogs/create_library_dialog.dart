import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/forms/create_library_form.dart';

class CreateLibraryDialog extends StatelessWidget {
  final String userId;
  const CreateLibraryDialog({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CreateLibraryForm(userId: userId),
      ),
    );
  }
}
