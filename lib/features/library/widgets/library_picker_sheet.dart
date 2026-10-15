import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/models/book_model.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/scanner/models/scored_book_result_model.dart';

enum LibraryPickerResult { saved, discarded }

/// Bottom sheet shown when leaving the scanner with unsaved results.
/// Lets the user pick an existing library (or create a new one) to save
/// into, or discard the scan and leave without saving.
class LibraryPickerSheet extends ConsumerStatefulWidget {
  final String userId;
  final List<ScoredBookResult> results;

  const LibraryPickerSheet({
    super.key,
    required this.userId,
    required this.results,
  });

  @override
  ConsumerState<LibraryPickerSheet> createState() => _LibraryPickerSheetState();
}

class _LibraryPickerSheetState extends ConsumerState<LibraryPickerSheet> {
  LibraryModel? _selectedLibrary;
  bool _isCreatingNew = false;
  bool _isSaving = false;
  final _newLibraryNameController = TextEditingController();

  @override
  void dispose() {
    _newLibraryNameController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_isSaving) return false;
    if (_isCreatingNew) {
      return _newLibraryNameController.text.trim().isNotEmpty;
    }
    return _selectedLibrary != null;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final repo = ref.read(libraryRepositoryProvider);

    try {
      final String libraryId;
      if (_isCreatingNew) {
        final now = DateTime.now();
        libraryId = await repo.createLibrary(
          LibraryModel(
            name: _newLibraryNameController.text.trim(),
            ownerId: widget.userId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        libraryId = _selectedLibrary!.id!;
      }

      for (final result in widget.results) {
        final book = result.book;
        await repo.addBook(
          libraryId,
          BookModel(
            title: book.title,
            author: book.author,
            isbn: book.isbn,
            coverUrl: book.coverUrl,
            addedAt: DateTime.now(),
          ),
        );
      }

      if (mounted) Navigator.of(context).pop(LibraryPickerResult.saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final librariesAsync = ref.watch(userLibrariesProvider(widget.userId));
    final bookCount = widget.results.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.collections_bookmark_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Save $bookCount ${bookCount == 1 ? "book" : "books"}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: librariesAsync.when(
                  data: (libraries) => _buildBody(libraries),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text("Couldn't load libraries: $e"),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(LibraryPickerResult.discarded),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canSave ? _save : null,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(List<LibraryModel> libraries) {
    if (_isCreatingNew) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _newLibraryNameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Library name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _isCreatingNew = false),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Choose existing library instead'),
          ),
        ],
      );
    }

    if (libraries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "You don't have any libraries yet.",
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _isCreatingNew = true),
            icon: const Icon(Icons.add),
            label: const Text('Create a library'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<LibraryModel>(
          initialValue: _selectedLibrary,
          decoration: const InputDecoration(
            labelText: 'Library',
            border: OutlineInputBorder(),
          ),
          items: libraries
              .map((lib) => DropdownMenuItem(value: lib, child: Text(lib.name)))
              .toList(),
          onChanged: (lib) => setState(() => _selectedLibrary = lib),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _isCreatingNew = true),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New library'),
        ),
      ],
    );
  }
}
