import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/forms/create_library_form.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

class CreateLibrarySheet extends StatelessWidget {
  final String userId;
  final LibraryModel? library; // set = editing this library
  const CreateLibrarySheet({super.key, required this.userId, this.library});

  static Future<void> show(
    BuildContext context, {
    required String userId,
    LibraryModel? library,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateLibrarySheet(userId: userId, library: library),
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
      child: CreateLibraryForm(userId: userId, library: library),
    );
  }
}
