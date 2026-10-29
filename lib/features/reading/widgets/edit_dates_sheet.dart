import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/reading/models/read_date.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/widgets/read_date_field.dart';

// Edits a read's start and end dates; null when cancelled,
// otherwise the (start, end) to save
Future<(ReadDate?, ReadDate?)?> showEditDatesSheet(
  BuildContext context,
  ReadModel read, {
  String title = 'Edit dates',
}) {
  return showModalBottomSheet<(ReadDate?, ReadDate?)>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EditDatesSheet(read: read, title: title),
  );
}

class EditDatesSheet extends StatefulWidget {
  final ReadModel read;
  final String title;

  const EditDatesSheet({
    super.key,
    required this.read,
    this.title = 'Edit dates',
  });

  @override
  State<EditDatesSheet> createState() => _EditDatesSheetState();
}

class _EditDatesSheetState extends State<EditDatesSheet> {
  ReadDate? _start;
  ReadDate? _end;

  // The same rules as ReadModel.withDates, so Save only sends dates that save
  String? get _error {
    // Local copies, so Dart knows they're non-null inside the checks
    final start = _start;
    final end = _end;

    if (!widget.read.isActive && end == null) return 'Pick an end date';
    if ((start?.isInFuture ?? false) || (end?.isInFuture ?? false)) {
      return "Dates can't be in the future";
    }
    if (start != null && end != null && !start.canStartBefore(end)) {
      return 'The start must be before the end';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _start = widget.read.startedAt;
    _end = widget.read.endedAt;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final error = _error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          // Only as tall as its content
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: textTheme.titleMedium),
            const SizedBox(height: 16),
            ReadDateField(
              label: 'Started',
              value: _start,
              isRequired: false,
              onChanged: (d) => setState(() => _start = d),
            ),
            // Only an ended read has an end date
            if (!widget.read.isActive) ...[
              const SizedBox(height: 16),
              ReadDateField(
                label: widget.read.status == BookStatus.dnf
                    ? 'Stopped'
                    : 'Finished',
                value: _end,
                isRequired: true,
                onChanged: (d) => setState(() => _end = d),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              // Null greys the button out
              onPressed: error == null
                  ? () => Navigator.pop(context, (_start, _end))
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
