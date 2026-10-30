import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/widgets/section_card.dart';
import 'package:shelf_snap/features/reading/models/reading_stats.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';

// Books finished, pages read and a month-by-month chart, for a chosen
// year or all time
class ReadingStatsScreen extends ConsumerStatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  ConsumerState<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends ConsumerState<ReadingStatsScreen> {
  final _now = DateTime.now();
  late int _year = _now.year; // the year picked in the menu
  bool _allTime = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final years = ref.watch(readYearsProvider);
    // Zeros for a moment while the reads load
    final stats =
        ref.watch(readingStatsProvider(_allTime ? null : _year)).valueOrNull ??
        const ReadingStats.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading stats'),
        titleTextStyle: textTheme.titleMedium,
        titleSpacing: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              // Tapping the year chip opens a menu of years with reads
              MenuAnchor(
                menuChildren: [
                  for (final y in years)
                    MenuItemButton(
                      onPressed: () => setState(() {
                        _year = y;
                        _allTime = false;
                      }),
                      trailingIcon: !_allTime && y == _year
                          ? const Icon(Icons.check_rounded, size: 18)
                          : null,
                      child: Text('$y'),
                    ),
                ],
                builder: (context, menu, _) => ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_year'),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down_rounded, size: 20),
                    ],
                  ),
                  selected: !_allTime,
                  onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('All time'),
                selected: _allTime,
                onSelected: (_) => setState(() => _allTime = true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Two rows of two tiles
          Row(
            children: [
              _StatTile(
                icon: Icons.check_circle_outline_rounded,
                value: stats.finished,
                label: 'Books finished',
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.menu_book_outlined,
                value: stats.pagesRead,
                label: 'Pages read',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatTile(
                icon: Icons.replay_rounded,
                value: stats.reReads,
                label: 'Re-reads',
              ),
              const SizedBox(width: 8),
              _StatTile(
                icon: Icons.do_not_disturb_on_outlined,
                value: stats.dnf,
                label: 'Did not finish',
              ),
            ],
          ),

          // Months only make sense within one year
          if (!_allTime) ...[
            const SizedBox(height: 16),
            SectionCard(
              icon: Icons.bar_chart_rounded,
              title: 'Finished per month',
              child: _MonthChart(
                counts: stats.finishedPerMonth,
                // Past years have no current month to mark
                currentMonth: _year == _now.year ? _now.month : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// A bordered tile with an icon, a big number and its label
class _StatTile extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 12),
            Text('$value', style: textTheme.headlineSmall),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Twelve bars, January first, scaled to the busiest month.
// Empty months show a short grey stub so the row never looks broken.
class _MonthChart extends StatelessWidget {
  final List<int> counts;
  final int? currentMonth; // 1–12, drawn darker; null for past years

  const _MonthChart({required this.counts, required this.currentMonth});

  static const _barArea = 120.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final most = counts.fold<int>(0, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 12; i++)
          Expanded(
            child: Column(
              children: [
                // The count sits on top of its bar
                Text(
                  counts[i] > 0 ? '${counts[i]}' : '',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: _barArea,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 14,
                      height: counts[i] == 0 ? 4 : _barArea * counts[i] / most,
                      decoration: BoxDecoration(
                        color: counts[i] == 0
                            ? AppColors.border
                            : i + 1 == currentMonth
                            ? AppColors.primaryDark
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  monthShort(i + 1)[0],
                  style: textTheme.labelSmall?.copyWith(
                    color: i + 1 == currentMonth
                        ? AppColors.text
                        : AppColors.hint,
                    fontWeight: i + 1 == currentMonth ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
