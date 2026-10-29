import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
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

      // The dialog already showed what was saved
      ref.read(scanSessionProvider.notifier).removeAll(results);
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
