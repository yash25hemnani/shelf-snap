import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/repositories/library_repository.dart';

class SaveToLibraryDialog extends ConsumerStatefulWidget {
  final List<BookModel> books;
  const SaveToLibraryDialog({super.key, required this.books});

  @override
  ConsumerState<SaveToLibraryDialog> createState() =>
      _SaveToLibraryDialogState();
}

class _SaveToLibraryDialogState extends ConsumerState<SaveToLibraryDialog> {
  String? _libraryId;
  bool _isSaving = false;

  Future<void> _save() async {
    final id = _libraryId;
    if (id == null) return;
    setState(() {
      _isSaving = true;
    });

    // Captured now: the dialog closes before the message shows
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .addBooks(id, widget.books);
      messenger.showMessage(LibraryRepository.savedMessage(result));
      if (!mounted) return;
      Navigator.pop(context, true); // tell the caller it worked
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not save: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser!.uid;
    final librariesAsync = ref.watch(userLibrariesProvider(userId));

    return AlertDialog(
      title: Text("Save ${widget.books.length} books"),
      content: librariesAsync.when(
        data: (libraries) => libraries.isEmpty
            ? const Text("No Libraries Yet")
            : DropdownButtonFormField<String>(
                initialValue: _libraryId,
                hint: const Text("Choose a library"),
                items: [
                  for (final lib in libraries)
                    DropdownMenuItem(value: lib.id, child: Text(lib.name)),
                ],
                onChanged: _isSaving
                    ? null
                    : (id) => setState(() {
                        _libraryId = id;
                      }),
              ),
        error: (e, _) => Text("Could not load libraries: $e"),
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _libraryId == null || _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Save"),
        ),
      ],
    );
  }
}
