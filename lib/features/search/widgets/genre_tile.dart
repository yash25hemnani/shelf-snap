import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/genre.dart';

// One genre on the Search shelf: a solid colour tile with white text
class GenreTile extends StatelessWidget {
  // Dark enough for white text. Five colours over two columns so the
  // same colour never stacks straight down a column.
  static const _fills = [
    AppColors.primary,
    AppColors.accent,
    AppColors.secondary,
    AppColors.primaryDark,
    AppColors.info,
  ];

  final Genre genre;
  final VoidCallback onTap;

  const GenreTile({super.key, required this.genre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _fills[genre.index % _fills.length],
      borderRadius: BorderRadius.circular(16),
      // Keeps the tap ripple inside the rounded corners
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Faint and partly cut off by the corner, like cover art
            Positioned(
              right: -8,
              bottom: -10,
              child: Icon(
                genre.icon,
                size: 56,
                color: AppColors.onPrimary.withValues(alpha: 0.18),
              ),
            ),
            Padding(
              // Right padding keeps long labels clear of the icon
              padding: const EdgeInsets.fromLTRB(14, 0, 36, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  genre.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: AppColors.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
