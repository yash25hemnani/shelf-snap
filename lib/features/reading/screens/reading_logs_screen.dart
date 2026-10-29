import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
import 'package:shelf_snap/features/reading/screens/reading_log_detail_screen.dart';
import 'package:shelf_snap/features/reading/widgets/reading_log_tile.dart';

// The user's reading list, filtered by status with chips at the top
class ReadingLogsScreen extends ConsumerWidget {
  const ReadingLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final filter = ref.watch(readingFilterProvider);
    // Words under 2 letters are skipped, so one letter still shows the full list
    final searching = BookModel.sanitizeWords(
      ref.watch(readingSearchQueryProvider),
    ).isNotEmpty;
    // Both are filtered by Firestore, so only matching books are downloaded
    final logsAsync = searching
        ? ref.watch(readingSearchProvider(filter))
        : ref.watch(readingLogsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My reading'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (text) =>
                  ref.read(readingSearchQueryProvider.notifier).state = text,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search title or author',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          // Filter chips, scrolling sideways; null is "All"
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final status in [null, ...BookStatus.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status?.label ?? 'All'),
                      selected: filter == status,
                      onSelected: (_) =>
                          ref.read(readingFilterProvider.notifier).state =
                              status,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Text(
                      searching
                          ? 'No books match your search'
                          : filter == null
                          ? 'No books in your reading list yet'
                          : 'No books here',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => ReadingLogTile(
                    log: logs[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReadingLogDetailScreen(readingKey: logs[i].id!),
                      ),
                    ),
                  ),
                );
              },
              error: (e, _) =>
                  Center(child: Text('Could not load reading list: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
