import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/forms/create_library_form.dart';

class CreateLibrarySheet extends StatelessWidget {
  final String userId;
  const CreateLibrarySheet({super.key, required this.userId});

  static Future<void> show(BuildContext context, {required String userId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateLibrarySheet(userId: userId),
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
      child: CreateLibraryForm(userId: userId),
    );
  }
}
