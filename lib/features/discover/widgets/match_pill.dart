import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/discover/models/taste_match.dart';

// The match label for one book. Only a strong match is filled, so the best
// books stand out in a long list.
class MatchPill extends StatelessWidget {
  final TasteMatch match;

  const MatchPill({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (match) {
      TasteMatch.strong => (
        AppColors.primary,
        AppColors.onPrimary,
        AppColors.primary,
      ),
      TasteMatch.partial => (
        AppColors.primarySoft,
        AppColors.primaryDark,
        AppColors.primarySoft,
      ),
      TasteMatch.unknown => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
        AppColors.surfaceMuted,
      ),
      TasteMatch.none => (
        AppColors.background,
        AppColors.hint,
        AppColors.border,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        match.label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}
