import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/dialogs/save_to_library_dialog.dart';
import 'package:shelf_snap/features/scanner/models/barcode_hit.dart';
import 'package:shelf_snap/features/scanner/providers/barcode_session_provider.dart';

class BarcodeSheet extends ConsumerWidget {
  const BarcodeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hits = ref.watch(barcodeSessionProvider).values.toList();
    final foundHits = hits.where((h) => h.status == HitStatus.found).toList();

    Future<void> openSave(
      BuildContext context,
      WidgetRef ref,
      List<BarcodeHit> foundHits,
    ) async {
      final saved = await showDialog(
        context: context,
        builder: (_) => SaveToLibraryDialog(
          books: [for (final hit in foundHits) hit.book!],
        ),
      );

      if (saved != true || !context.mounted) return;

      final notifier = ref.read(barcodeSessionProvider.notifier);

      for (final h in foundHits) {
        notifier.remove(h.isbn);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${foundHits.length} books')),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${foundHits.length} of ${hits.length} found",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: foundHits.isEmpty
                      ? null
                      : () => openSave(context, ref, foundHits),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),

          if (hits.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text("No barcodes scanned yet."),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hits.length,
                itemBuilder: (context, i) {
                  final hit = hits[i];

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
    final book = hit.book;

    return switch (hit.status) {
      HitStatus.loading => ListTile(
        leading: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: const Text('Looking up…'),
        subtitle: Text(hit.isbn),
      ),
      HitStatus.found => ListTile(
        leading: book!.coverUrl == null
            ? const Icon(Icons.menu_book)
            : Image.network(
                book.coverUrl!,
                width: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.menu_book),
              ),
        title: Text(book.title),
        subtitle: Text(book.authorLine ?? 'Unknown author'),
      ),
      HitStatus.notFound => ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Not found'),
        subtitle: Text(hit.isbn),
      ),
    };
  }
}
