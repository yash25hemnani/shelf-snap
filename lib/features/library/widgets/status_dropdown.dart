import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';

class StatusDropdown extends StatelessWidget {
  final BookStatus? value; // null = no log yet
  final ValueChanged<BookStatus>? onChanged; // null = disabled
  const StatusDropdown({super.key, this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<BookStatus>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: AppColors.background,
      hint: const Text('Add to reading list'),
      items: [
        for (final s in BookStatus.values)
          DropdownMenuItem(value: s, child: Text(s.label)),
      ],
      onChanged: onChanged == null
          ? null
          : (status) {
              if (status != null) onChanged!(status);
            },
    );
  }
}
