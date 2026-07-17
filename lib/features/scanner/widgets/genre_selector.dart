import 'package:flutter/material.dart';

class GenreSelector extends StatefulWidget {
  final Set<String> watchedGenres;
  final ValueChanged<Set<String>> onChanged;

  const GenreSelector({
    super.key,
    required this.watchedGenres,
    required this.onChanged,
  });

  static const List<String> availableGenres = [
    'Fiction', 'Non-Fiction', 'Mystery', 'Thriller', 'Romance',
    'Science Fiction', 'Fantasy', 'Horror', 'Biography', 'History',
    'Self Help', 'Business', 'Philosophy', 'Psychology', 'Travel',
    'Children', 'Young Adult', 'Poetry', 'Comics', 'Cookbooks',
  ];

  @override
  State<GenreSelector> createState() => _GenreSelectorState();
}

class _GenreSelectorState extends State<GenreSelector> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.watchedGenres);
  }

  void _toggle(String genre, bool val) {
    setState(() {
      if (val) {
        _selected.add(genre);
      } else {
        _selected.remove(genre);
      }
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Vibrates and highlights the card when a scanned book matches.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...GenreSelector.availableGenres.map((genre) {
          final selected = _selected.contains(genre);
          return GestureDetector(
            onTap: () => _toggle(genre, !selected),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      genre,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}