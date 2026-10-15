import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

class AddBookForm extends ConsumerStatefulWidget {
  final String libraryId;
  const AddBookForm({super.key, required this.libraryId});

  @override
  ConsumerState<AddBookForm> createState() => _AddBookFormState();
}

class _AddBookFormState extends ConsumerState<AddBookForm> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  // Empty text field -> null, so Firestore stores null rather than ""
  String? _optional(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(libraryRepositoryProvider);

    final book = BookModel(
      title: _titleController.text.trim(),
      author: _optional(_authorController),
      isbn: _optional(_isbnController)?.replaceAll('-', ''),
      addedAt: DateTime.now(),
    );

    setState(() => _isSaving = true);

    try {
      await repository.addBook(widget.libraryId, book);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Could not add book: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Add book", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Title"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Enter a title";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _authorController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Author (optional)"),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _isbnController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _onSubmit(),
              decoration: const InputDecoration(labelText: "ISBN (optional)"),
              validator: (value) {
                final isbn = (value ?? '').trim().replaceAll('-', '');
                if (isbn.isEmpty) return null; // optional
                if (isbn.length != 10 && isbn.length != 13) {
                  return "ISBN must be 10 or 13 digits";
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSaving ? null : _onSubmit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Add"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
