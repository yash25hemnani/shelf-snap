import 'package:flutter/material.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/features/reading/models/read_date.dart';

class ReadDateField extends StatelessWidget {
  final String label;
  final ReadDate? value;
  final bool isRequired;
  final ValueChanged<ReadDate?> onChanged;

  const ReadDateField({
    super.key,
    required this.label,
    this.value,
    required this.isRequired,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = value;
    final month = date?.month;
    // 0 days until a month is picked, so the Day list is empty
    final days = date == null || month == null
        ? 0
        : DateUtils.getDaysInMonth(date.year, month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            TextButton(
              onPressed: () => onChanged(ReadDate.today()),
              child: const Text('Today'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: date?.day,
                hint: const Text('Day'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('–')),
                  for (var d = 1; d <= days; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                // A day needs its month
                onChanged: date == null || month == null
                    ? null
                    : (d) => onChanged(ReadDate(date.year, month, d)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: month,
                hint: const Text('Month'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('–')),
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text(monthShort(m))),
                ],
                onChanged: date == null
                    ? null
                    : (m) {
                        // Keep the day only if it fits the new month
                        final d = date.day;
                        final keepDay =
                            m != null &&
                            d != null &&
                            d <= DateUtils.getDaysInMonth(date.year, m);
                        onChanged(ReadDate(date.year, m, keepDay ? d : null));
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: date?.year,
                hint: const Text('Year'),
                items: [
                  if (!isRequired)
                    const DropdownMenuItem(value: null, child: Text('Not set')),
                  for (var y = now.year; y >= now.year - 100; y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (y) {
                  if (y == null) return onChanged(null);

                  // Keep the day only if it fits, e.g. 29 Feb in a non-leap year
                  final d = date?.day;
                  final keepDay =
                      month != null &&
                      d != null &&
                      d <= DateUtils.getDaysInMonth(y, month);
                  onChanged(ReadDate(y, month, keepDay ? d : null));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
