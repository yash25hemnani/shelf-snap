import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/forms/create_library_form.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

// Full page for creating a library, or editing one when [library] is set
class CreateLibraryScreen extends StatelessWidget {
  final String userId;
  final LibraryModel? library;
  // Starting choice for a new library, from the tab it was opened on
  final LibraryAccess initialAccess;
  const CreateLibraryScreen({
    super.key,
    required this.userId,
    this.library,
    this.initialAccess = LibraryAccess.private,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Same size as the library name on library cards
        titleTextStyle: Theme.of(context).textTheme.titleMedium,
        // Title sits right after the back arrow
        titleSpacing: 0,
        title: Text(library == null ? 'Create Library' : 'Edit Library'),
      ),
      body: SafeArea(
        child: CreateLibraryForm(
          userId: userId,
          library: library,
          initialAccess: initialAccess,
        ),
      ),
    );
  }
}
