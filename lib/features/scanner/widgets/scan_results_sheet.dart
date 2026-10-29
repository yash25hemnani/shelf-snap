import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/repositories/library_repository.dart';
import 'package:shelf_snap/features/library/widgets/library_picker_bar.dart';
import 'package:shelf_snap/features/scanner/providers/scan_session_provider.dart';

// Books found in shelf photos, with a library picker and Save at the top,
// the same as the barcode sheet
class ScanResultsSheet extends ConsumerStatefulWidget {
  const ScanResultsSheet({super.key});

  @override
  ConsumerState<ScanResultsSheet> createState() => _ScanResultsSheetState();
}

class _ScanResultsSheetState extends ConsumerState<ScanResultsSheet> {
  String? _libraryId;
  bool _isSaving = false;

  void _selectLibrary(String id) {
    ref.read(lastLibraryIdProvider.notifier).state = id;
    setState(() => _libraryId = id);
  }

  // The user's pick, else the last-used library, else the first one.
  // Each is checked against the list, since a library can be deleted or left.
  String _pickLibrary(List<LibraryModel> libraries) {
    final ids = libraries.map((l) => l.id).toSet();
    final picked = _libraryId;
    final last = ref.read(lastLibraryIdProvider);

    if (picked != null && ids.contains(picked)) return picked;
    if (last != null && ids.contains(last)) return last;
    return libraries.first.id!; // libraries from Firestore always have an id
  }

  Future<void> _save(String libraryId) async {
    final messenger = ScaffoldMessenger.of(context);
    final results = ref.read(scanSessionProvider).results;
    setState(() => _isSaving = true);

    try {
      final result = await ref.read(libraryRepositoryProvider).addBooks(
        libraryId,
        [for (final r in results) r.book],
      );

      ref.read(scanSessionProvider.notifier).removeAll(results);
      messenger.showMessage(LibraryRepository.savedMessage(result));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showError('Could not save: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser!.uid;
    final librariesAsync = ref.watch(userLibrariesProvider(userId));
    final results = ref.watch(scanSessionProvider).results;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${results.length} books found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                librariesAsync.when(
                  data: (libraries) {
                    if (libraries.isEmpty) {
                      return const Text(
                        'Create a library first to save books.',
                      );
                    }
                    final libraryId = _pickLibrary(libraries);
                    return LibraryPickerBar(
                      libraries: libraries,
                      selectedId: libraryId,
                      onChanged: _selectLibrary,
                      isSaving: _isSaving,
                      onSave: results.isEmpty ? null : () => _save(libraryId),
                    );
                  },
                  error: (e, _) => Text('Could not load libraries: $e'),
                  loading: () => const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            ),
          ),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No books recognised. Try again closer to the shelf.',
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final r = results[i];
                  return Dismissible(
                    key: ObjectKey(r),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Theme.of(context).colorScheme.error,
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onError,
                      ),
                    ),
                    onDismissed: (_) =>
                        ref.read(scanSessionProvider.notifier).removeAt(i),
                    child: ListTile(
                      leading: _Cover(url: r.book.coverUrl),
                      title: Text(r.book.title),
                      subtitle: Text(r.book.authorLine ?? 'Unknown author'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Small book cover, with a placeholder while loading or when there's none
class _Cover extends StatelessWidget {
  final String? url;

  const _Cover({this.url});

  static const _width = 40.0;
  static const _height = 60.0;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: _width,
      height: _height,
      color: AppColors.surfaceMuted,
      child: const Icon(Icons.menu_book_rounded, color: AppColors.hint),
    );
    final coverUrl = url;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: coverUrl == null
          ? placeholder
          : Image.network(
              coverUrl,
              width: _width,
              height: _height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
