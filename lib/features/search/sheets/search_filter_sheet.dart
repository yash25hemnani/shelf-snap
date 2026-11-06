import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/models/genre.dart';
import 'package:shelf_snap/features/search/models/search_query.dart';

// Genre filter for a running search. Edits a draft and returns it only on
// "Show results", since each genre is its own Open Library request.
class SearchFilterSheet extends StatefulWidget {
  final Set<Genre> genres;

  const SearchFilterSheet({super.key, required this.genres});

  // The picked genres, or null if the sheet was dismissed
  static Future<Set<Genre>?> show(
    BuildContext context, {
    required Set<Genre> genres,
  }) {
    return showModalBottomSheet<Set<Genre>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SearchFilterSheet(genres: genres),
    );
  }

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late final Set<Genre> _draft = {...widget.genres};

  void _toggle(Genre genre, bool selected) {
    setState(() => selected ? _draft.add(genre) : _draft.remove(genre));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final full = _draft.length >= SearchQuery.maxGenres;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Genres', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pick up to ${SearchQuery.maxGenres}',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in Genre.values)
                  FilterChip(
                    label: Text(genre.label),
                    selected: _draft.contains(genre),
                    // Once full, only picked ones can be tapped
                    onSelected: _draft.contains(genre) || !full
                        ? (value) => _toggle(genre, value)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _draft.isEmpty
                      ? null
                      : () => setState(_draft.clear),
                  child: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: const Text('Show results'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
