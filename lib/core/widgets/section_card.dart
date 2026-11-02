import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';

// A bordered white card with a title, an optional icon in a soft green
// circle before it, an optional action on the right, and its content below
class SectionCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  const SectionCard({
    super.key,
    this.icon,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    final trailing = this.trailing;
    // Without the icon circle the title needs the full left padding
    final left = icon == null ? 16.0 : 12.0;

    return Container(
      padding: EdgeInsets.fromLTRB(left, 12, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed height so cards with and without a button line up
          SizedBox(
            height: 40,
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 22, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Right padding matches the left, since the card's is smaller
          // to leave room for the action button
          Padding(
            padding: EdgeInsets.only(right: left - 8),
            child: child,
          ),
        ],
      ),
    );
  }
}

// Small soft green pill, like the progress percent
class SoftPill extends StatelessWidget {
  final String label;

  const SoftPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
