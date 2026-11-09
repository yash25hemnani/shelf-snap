import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/widgets/section_card.dart';
import 'package:shelf_snap/features/library/models/book_model.dart';
import 'package:shelf_snap/features/library/providers/wikipedia_provider.dart';

// Facts and the intro from the book's Wikipedia page. Takes no space when
// the book has no page or the lookup fails, since most editions' own
// details are already on the page above it.
class WikipediaCard extends ConsumerStatefulWidget {
  final BookModel book;

  const WikipediaCard({super.key, required this.book});

  @override
  ConsumerState<WikipediaCard> createState() => _WikipediaCardState();
}

class _WikipediaCardState extends ConsumerState<WikipediaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    // The backend matches on the author's last name, so one is required
    if (book.title == BookModel.unknownTitle || book.authors.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final wikiAsync = ref.watch(
      wikiBookProvider((title: book.title, author: book.authors.first)),
    );

    return wikiAsync.when(
      loading: () => _wrap(
        Row(
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Looking it up on Wikipedia', style: muted),
          ],
        ),
      ),
      error: (e, _) {
        debugPrint('Wikipedia lookup failed: $e');
        return const SizedBox.shrink();
      },
      data: (wiki) {
        if (wiki == null) return const SizedBox.shrink();
        final summary = wiki.summary;

        return _wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wiki.publishedYear case final year?)
                _FactRow(label: 'First published', value: year),
              if (wiki.pageCount case final pages?)
                _FactRow(label: 'Pages', value: '$pages'),
              if (wiki.series case final series?)
                _FactRow(label: 'Series', value: series),
              if (wiki.genres.isNotEmpty)
                _FactRow(label: 'Genres', value: wiki.genres.join(', ')),
              if (wiki.country case final country?)
                _FactRow(label: 'Country', value: country),
              if (wiki.language case final language?)
                _FactRow(label: 'Language', value: language),
              if (summary != null) ...[
                if (wiki.hasFacts) const SizedBox(height: 12),
                Text(
                  summary,
                  maxLines: _expanded ? null : 5,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
                if (summary.length > 250)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(_expanded ? 'Show less' : 'Read more'),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              // Wikipedia text is CC BY-SA, so it's credited with the page
              Text(
                'From Wikipedia: ${wiki.title}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.hint),
              ),
            ],
          ),
        );
      },
    );
  }

  // The card plus the gap below it, so a hidden card leaves no gap
  Widget _wrap(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        icon: Icons.travel_explore_rounded,
        title: 'More details',
        child: child,
      ),
    );
  }
}

// A label on the left and its value on the right
class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodyMedium),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
