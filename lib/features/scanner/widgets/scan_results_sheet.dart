import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/dialogs/save_to_library_dialog.dart';
import 'package:shelf_snap/features/scanner/providers/scan_session_provider.dart';

class ScanResultsSheet extends ConsumerWidget {
  const ScanResultsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(scanSessionProvider).results;

    Future<void> openSave() async {
      final saved = await showDialog(
        context: context,
        builder: (_) =>
            SaveToLibraryDialog(books: [for (final res in results) res.book]),
      );

      if (saved != true || !context.mounted) return;

      ref.read(scanSessionProvider.notifier).removeAll(results);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved ${results.length} books')));
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
                    '${results.length} books found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonal(
                  onPressed: results.isEmpty ? null : openSave,
                  child: const Text('Save'),
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
