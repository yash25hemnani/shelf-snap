import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
import 'package:shelf_snap/features/reading/widgets/reading_log_tile.dart';

// The user's reading list, filtered by status with chips at the top
class ReadingLogsScreen extends ConsumerWidget {
  const ReadingLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final filter = ref.watch(readingFilterProvider);
    // Filtered by Firestore, so only the chosen status is downloaded
    final logsAsync = ref.watch(readingLogsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My reading'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
      ),
      body: Column(
        children: [
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
                      filter == null
                          ? 'No books in your reading list yet'
                          : 'No books here',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => ReadingLogTile(log: logs[i]),
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
