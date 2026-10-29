import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/invites/screens/notifications_screen.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/create_library_screen.dart';
import 'package:shelf_snap/features/library/screens/library_detail_screen.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/models/reading_stats.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
import 'package:shelf_snap/features/reading/screens/reading_log_detail_screen.dart';
import 'package:shelf_snap/features/reading/screens/reading_logs_screen.dart';
import 'package:shelf_snap/features/reading/screens/reading_stats_screen.dart';

// The first tab: a greeting, this year's numbers, books in progress and
// the user's libraries. Every section shows, with its own empty state.
class HomeScreen extends ConsumerWidget {
  final VoidCallback onOpenLibraries; // jumps to the Library tab

  const HomeScreen({super.key, required this.onOpenLibraries});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = AuthService().currentUser?.uid;

    // AuthGate handles login; build must not navigate
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final profile = ref.watch(userProfileProvider(uid)).valueOrNull;
    final inviteCount =
        ref.watch(incomingInvitesProvider(uid)).valueOrNull?.length ?? 0;
    final year = DateTime.now().year;
    final stats =
        ref.watch(readingStatsProvider(year)).valueOrNull ??
        const ReadingStats.empty();

    // Reading first, then paused
    final inProgress = [
      ...?ref.watch(readingLogsProvider(BookStatus.reading)).valueOrNull,
      ...?ref.watch(readingLogsProvider(BookStatus.paused)).valueOrNull,
    ];
    final libraries =
        ref.watch(userLibrariesProvider(uid)).valueOrNull ?? const [];

    return Scaffold(
      // No app bar: the header runs up behind the status bar
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark, // dark status bar icons
        child: ListView(
          // Extra bottom space so the last item clears the navbar
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Header(
              name: profile?.name.split(' ').first,
              bell: IconButton(
                tooltip: 'Notifications',
                // The badge shows the number of pending invites
                icon: Badge.count(
                  count: inviteCount,
                  isLabelVisible: inviteCount > 0,
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                onPressed: () => _push(context, const NotificationsScreen()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatsCard(
                    year: year,
                    stats: stats,
                    readingNow: inProgress.length,
                    onTap: () => _push(context, const ReadingStatsScreen()),
                  ),
                  const SizedBox(height: 24),

                  _SectionTitle(
                    icon: Icons.menu_book_rounded,
                    title: 'Currently reading',
                    onSeeAll: () => _push(context, const ReadingLogsScreen()),
                  ),
                  const SizedBox(height: 8),
                  if (inProgress.isEmpty)
                    _EmptyReadingCard(onOpenLibraries: onOpenLibraries)
                  else
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        // Lets the cards scroll to the screen edge
                        clipBehavior: Clip.none,
                        itemCount: inProgress.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final log = inProgress[i];
                          return _ContinueCard(
                            log: log,
                            onTap: log.id == null
                                ? null
                                : () => _push(
                                    context,
                                    ReadingLogDetailScreen(readingKey: log.id!),
                                  ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  _SectionTitle(
                    icon: Icons.layers_rounded,
                    title: 'Your libraries',
                    onSeeAll: onOpenLibraries,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        for (final library in libraries) ...[
                          _LibraryTile(
                            library: library,
                            onTap: () => _push(
                              context,
                              LibraryDetailScreen(library: library),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        _NewLibraryTile(
                          onTap: () =>
                              _push(context, CreateLibraryScreen(userId: uid)),
                        ),
                        // With no libraries, explain the lone + card
                        if (libraries.isEmpty)
                          Container(
                            width: 180,
                            padding: const EdgeInsets.only(left: 16),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Create a library to start adding books',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                      ],
                    ),
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

// "Good afternoon," with the first name large under it, on a soft green
// fade that runs up behind the status bar
class _Header extends StatelessWidget {
  final String? name; // first name; null while the profile loads
  final Widget bell;

  const _Header({required this.name, required this.bell});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = this.name;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 16,
        8,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primarySoft, AppColors.background],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null ? _greeting : '$_greeting,',
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (name != null)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // GoogleFonts.dmSans so the w700 font file loads
                    style: GoogleFonts.dmSans(
                      textStyle: textTheme.displaySmall,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
              ],
            ),
          ),
          bell,
        ],
      ),
    );
  }
}

// Section heading with an optional "See all" on the right
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionTitle({required this.icon, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // Filled green square with a white icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (onSeeAll != null)
            IconButton(
              tooltip: 'See all',
              onPressed: onSeeAll,
              icon: const _SeeAll(),
            ),
        ],
      ),
    );
  }
}

// A green "›" at the end of every section heading
class _SeeAll extends StatelessWidget {
  const _SeeAll();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chevron_right_rounded, color: AppColors.primary);
  }
}

// Empty "Currently reading": a bordered card the size of a book card,
// with a hint and a button to the Library tab, centred
class _EmptyReadingCard extends StatelessWidget {
  final VoidCallback onOpenLibraries;

  const _EmptyReadingCard({required this.onOpenLibraries});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Start a book from one of your libraries',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onOpenLibraries,
            icon: const Icon(Icons.bookmarks_outlined),
            label: const Text('Open libraries'),
          ),
        ],
      ),
    );
  }
}

// This year's totals and a small month chart; opens Reading stats
class _StatsCard extends StatelessWidget {
  final int year;
  final ReadingStats stats;
  final int readingNow;
  final VoidCallback onTap;

  const _StatsCard({
    required this.year,
    required this.stats,
    required this.readingNow,
    required this.onTap,
  });

  // 3420 → "3,420"
  static String _thousands(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final counts = stats.finishedPerMonth;
    final most = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final currentMonth = DateTime.now().month;

    // No frame of its own: the three numbers are the cards
    return Material(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Same filled green square as the section titles
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      size: 18,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Your $year', style: textTheme.titleMedium),
                  ),
                  // Not a button: the whole card already opens stats
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _SeeAll(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _BigNumber(
                    icon: Icons.check_circle_outline_rounded,
                    value: '${stats.finished}',
                    label: 'books finished',
                  ),
                  const SizedBox(width: 8),
                  _BigNumber(
                    icon: Icons.description_outlined,
                    value: _thousands(stats.pagesRead),
                    label: 'pages read',
                  ),
                  const SizedBox(width: 8),
                  _BigNumber(
                    icon: Icons.schedule_rounded,
                    value: '$readingNow',
                    label: 'reading now',
                  ),
                ],
              ),
              // Month bars only once a book is finished
              if (stats.finished > 0) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 32,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 12; i++)
                        Expanded(
                          child: Container(
                            height: counts[i] == 0 ? 3 : 32 * counts[i] / most,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: counts[i] == 0
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : i + 1 == currentMonth
                                  ? AppColors.primaryDark
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// One stat in its own bordered card: icon, large number, small label.
// Takes a third of the row.
class _BigNumber extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _BigNumber({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Book cover with a grey book icon when there's no image
class _Cover extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const _Cover({required this.url, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    const placeholder = ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: Icon(Icons.book, color: AppColors.hint)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

// A book in progress: cover, title, author, and how far along it is
class _ContinueCard extends StatelessWidget {
  final ReadingLogModel log;
  final VoidCallback? onTap;

  const _ContinueCard({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final read = log.latestRead;
    final pageCount = (log.pageCount ?? 0) > 0 ? log.pageCount : null;
    final fraction = read?.fraction(pageCount);
    final paused = log.status == BookStatus.paused;

    final progressLabel = read == null
        ? log.status.label
        : pageCount != null
        ? 'Page ${read.progressValue} of $pageCount'
        : fraction != null
        ? '${(fraction * 100).round()}%'
        : 'Add the page count';

    return SizedBox(
      width: 280,
      child: Material(
        color: AppColors.background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Cover(url: log.coverUrl, width: 68, height: 104),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                      Text(
                        log.authors.isEmpty
                            ? 'Unknown author'
                            : log.authors.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        paused ? 'Paused · $progressLabel' : progressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: paused
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: fraction ?? 0,
                          minHeight: 6,
                          color: paused ? AppColors.warning : AppColors.primary,
                          backgroundColor: AppColors.surfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Shared frame for the library row: a bordered card 140 wide
class _TileFrame extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _TileFrame({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Material(
        color: AppColors.background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

// One library: its banner photo, name and book count
class _LibraryTile extends StatelessWidget {
  final LibraryModel library;
  final VoidCallback onTap;

  const _LibraryTile({required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = library.bookCount;

    return _TileFrame(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image(
            image: library.bannerImage,
            height: 84,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              library.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              count == 1 ? '1 book' : '$count books',
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Always last in the library row: opens Create library
class _NewLibraryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _NewLibraryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 8),
          Text('New library', style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
