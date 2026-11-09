import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

// Picks genres from the 24 fixed ones. Used by the Search filter, the
// Discover taste and the Discovered list filter. Edits a draft and returns
// it only on the action button; null when dismissed.
class GenrePickerSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Set<Genre> selected;
  final int? max; // null = no limit
  final String actionLabel;

  const GenrePickerSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    this.max,
    required this.actionLabel,
  });

  static Future<Set<Genre>?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Set<Genre> selected,
    int? max,
    required String actionLabel,
  }) {
    return showModalBottomSheet<Set<Genre>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GenrePickerSheet(
        title: title,
        subtitle: subtitle,
        selected: selected,
        max: max,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  State<GenrePickerSheet> createState() => _GenrePickerSheetState();
}

class _GenrePickerSheetState extends State<GenrePickerSheet> {
  late final Set<Genre> _draft = {...widget.selected};

  bool get _full => widget.max != null && _draft.length >= widget.max!;

  void _toggle(Genre genre) {
    setState(() {
      if (_draft.remove(genre)) return;
      // With a limit of one, picking another genre swaps it in
      if (widget.max == 1) _draft.clear();
      _draft.add(genre);
    });
  }

  String get _countLabel {
    final max = widget.max;
    if (max != null && max > 1) return '${_draft.length} of $max';
    return _draft.isEmpty ? 'None picked' : '${_draft.length} picked';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = widget.subtitle;
    // Swapping is allowed at a limit of one, so nothing is greyed out then
    final locks = _full && widget.max != 1;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(widget.title, style: textTheme.titleLarge),
                      ),
                      Text(
                        _countLabel,
                        style: textTheme.labelLarge?.copyWith(
                          color: _draft.isEmpty
                              ? AppColors.hint
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: Genre.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final genre = Genre.values[index];
                  final selected = _draft.contains(genre);
                  return _GenreChoice(
                    genre: genre,
                    selected: selected,
                    enabled: selected || !locks,
                    onTap: () => _toggle(genre),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                    ),
                    child: Text(widget.actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// One genre as a full-width row with a coloured stripe down its left edge,
// like a book spine. Picking it tints the border and fills the check.
class _GenreChoice extends StatelessWidget {
  static const _stripeWidth = 6.0;
  static const _height = 56.0;

  final Genre genre;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _GenreChoice({
    required this.genre,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill =
        AppColors.genreFills[genre.index % AppColors.genreFills.length];
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: duration,
      child: Material(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? fill : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        // Keeps the stripe and ripple inside the rounded corners
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: _height,
            child: Row(
              children: [
                Container(width: _stripeWidth, color: fill),
                const SizedBox(width: 14),
                Icon(genre.icon, size: 22, color: fill),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    genre.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                AnimatedSwitcher(
                  duration: duration,
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    size: 22,
                    color: selected ? fill : AppColors.border,
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
