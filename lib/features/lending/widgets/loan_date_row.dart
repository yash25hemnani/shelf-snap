import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';

// A tappable date with a clear button once it's set
class LoanDateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const LoanDateRow({
    super.key,
    required this.icon,
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final date = this.date;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryDark),
      title: Text(label),
      subtitle: Text(
        date == null ? 'Not set' : dayMonth(date),
        style: TextStyle(
          color: date == null ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
      trailing: date == null
          ? null
          : IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded),
              onPressed: onClear,
            ),
      onTap: onTap,
    );
  }
}
