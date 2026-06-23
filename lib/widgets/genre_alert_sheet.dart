import 'package:flutter/material.dart';
import 'package:shelf_snap/widgets/genre_selector.dart';

class GenreAlertSheet extends StatelessWidget {
  final Set<String> watchedGenres;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onClearAll;

  const GenreAlertSheet({
    super.key,
    required this.watchedGenres,
    required this.onChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
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
                      const Icon(Icons.notifications_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Genre alerts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (watchedGenres.isNotEmpty)
                        TextButton(
                          onPressed: onClearAll,
                          child: const Text('Clear all'),
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
                child: GenreSelector(
                  key: ValueKey(watchedGenres.length),
                  watchedGenres: watchedGenres,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}