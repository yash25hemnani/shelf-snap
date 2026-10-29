import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/repositories/library_repository.dart';
import 'package:shelf_snap/features/library/widgets/library_picker_bar.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';
import 'package:shelf_snap/features/scanner/providers/barcode_session_provider.dart';

class BarcodeSheet extends ConsumerStatefulWidget {
  const BarcodeSheet({super.key});

  @override
  ConsumerState<BarcodeSheet> createState() => _BarcodeSheetState();
}

class _BarcodeSheetState extends ConsumerState<BarcodeSheet> {
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

  Future<void> _save(String libraryId, List<BarcodeHit> hits) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);

    try {
      final result = await ref.read(libraryRepositoryProvider).addBooks(
        libraryId,
        [for (final hit in hits) hit.book!],
      );

      final notifier = ref.read(barcodeSessionProvider.notifier);
      for (final hit in hits) {
        notifier.remove(hit.isbn);
      }
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

    // Only books with a match; failed and unmatched scans stay off the sheet
    final foundHits = ref
        .watch(barcodeSessionProvider)
        .values
        .where((h) => h.status == HitStatus.found)
        .toList();

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
                  '${foundHits.length} books found',
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
                      onSave: foundHits.isEmpty
                          ? null
                          : () => _save(libraryId, foundHits),
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

          if (foundHits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No books found yet.'),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: foundHits.length,
                itemBuilder: (context, i) {
                  final hit = foundHits[i];

                  return Dismissible(
                    key: ValueKey(hit.isbn),
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
                    onDismissed: (_) => ref
                        .read(barcodeSessionProvider.notifier)
                        .remove(hit.isbn),
                    child: _HitTile(hit: hit),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final BarcodeHit hit;

  @override
  Widget build(BuildContext context) {
    // The sheet only lists found hits, so the book is always there
    final book = hit.book!;

    return ListTile(
      leading: book.coverUrl == null
          ? const Icon(Icons.menu_book)
          : Image.network(
              book.coverUrl!,
              width: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.menu_book),
            ),
      title: Text(book.title),
      subtitle: Text(book.authorLine ?? 'Unknown author'),
    );
  }
}
