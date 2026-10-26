import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

// Compact status pill; opens a menu sized to its options, just below the pill
class StatusDropdown extends StatelessWidget {
  final BookStatus? value; // null = no log yet
  final ValueChanged<BookStatus>? onChanged; // null = disabled
  const StatusDropdown({super.key, this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = value;

    return PopupMenuButton<BookStatus>(
      enabled: onChanged != null,
      initialValue: current,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: AppColors.background,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => [
        for (final s in BookStatus.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                // Check on the current status; empty space keeps labels aligned
                SizedBox(
                  width: 24,
                  child: s == current
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: _StatusPill(
        label: current?.label ?? 'Add to reading list',
        active: current != null,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool active; // true once the book has a status
  const _StatusPill({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primaryDark : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // hug the text, don't stretch
        children: [
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: fg),
        ],
      ),
    );
  }
}
