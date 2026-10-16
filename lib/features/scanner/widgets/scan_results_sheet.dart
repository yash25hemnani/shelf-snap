import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/scanner/providers/scan_session_provider.dart';

class ScanResultsSheet extends ConsumerWidget {
  const ScanResultsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(scanSessionProvider).results;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${results.length} books found',
              style: Theme.of(context).textTheme.titleMedium,
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
                      color: Colors.red[900],
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) =>
                        ref.read(scanSessionProvider.notifier).removeAt(i),
                    child: ListTile(
                      title: Text(r.book.title),
                      subtitle: Text(r.book.author ?? 'Unknown author'),
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
