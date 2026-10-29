import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/repositories/library_repository.dart';

class SaveToLibrarySheet extends ConsumerStatefulWidget {
  final BookModel book;
  const SaveToLibrarySheet({super.key, required this.book});

  // Resolves to true once the book is saved
  static Future<bool?> show(BuildContext context, {required BookModel book}) {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (_) => SaveToLibrarySheet(book: book),
    );
  }

  @override
  ConsumerState<SaveToLibrarySheet> createState() => _SaveToLibrarySheetState();
}

class _SaveToLibrarySheetState extends ConsumerState<SaveToLibrarySheet> {
  String? _libraryId;
  bool _isSaving = false;

  Future<void> _save() async {
    final id = _libraryId;
    if (id == null) return;
    setState(() {
      _isSaving = true;
    });

    // Captured now: the sheet closes before the message shows
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await ref.read(libraryRepositoryProvider).addBooks(id, [
        widget.book,
      ]);
      messenger.showMessage(LibraryRepository.savedMessage(result));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = AuthService().currentUser!.uid;
    final librariesAsync = ref.watch(userLibrariesProvider(userId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add to library', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            librariesAsync.when(
              data: (libraries) => libraries.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No libraries yet',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _libraryId,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      dropdownColor: AppColors.background,
                      elevation: 2,
                      menuMaxHeight: 320,
                      hint: const Text('Choose a library'),
                      items: [
                        for (final lib in libraries)
                          DropdownMenuItem(
                            value: lib.id,
                            child: Text(
                              lib.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (id) => setState(() {
                              _libraryId = id;
                            }),
                    ),
              error: (e, _) => Text('Could not load libraries: $e'),
              loading: () => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _libraryId == null || _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                textStyle: theme.textTheme.titleMedium,
              ),
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                textStyle: theme.textTheme.titleMedium,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
