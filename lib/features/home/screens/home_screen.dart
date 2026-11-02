import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/date_format.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/clay_avatar.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/friends/models/feed_item.dart';
import 'package:shelf_snap/features/friends/providers/feed_provider.dart';
import 'package:shelf_snap/features/friends/screens/friend_screen.dart';
import 'package:shelf_snap/features/friends/screens/friends_screen.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/invites/screens/notifications_screen.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/create_library_screen.dart';
import 'package:shelf_snap/features/library/screens/library_detail_screen.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';
import 'package:shelf_snap/features/reading/models/read_model.dart';
import 'package:shelf_snap/features/reading/models/reading_log_model.dart';
import 'package:shelf_snap/features/reading/models/reading_stats.dart';
import 'package:shelf_snap/features/reading/providers/reading_log_provider.dart';
import 'package:shelf_snap/features/reading/screens/reading_log_detail_screen.dart';
import 'package:shelf_snap/features/reading/screens/reading_logs_screen.dart';
import 'package:shelf_snap/features/reading/screens/reading_stats_screen.dart';
import 'package:shelf_snap/features/reading/widgets/number_dialog.dart';

// Progress text and bar fill for a book in progress, shared by both cards
({String label, double? fraction}) _progressOf(ReadingLogModel log) {
  final read = log.latestRead;
  final pageCount = (log.pageCount ?? 0) > 0 ? log.pageCount : null;
  final fraction = read?.fraction(pageCount);

  final label = read == null
      ? log.status.label
      : pageCount != null
      ? 'Page ${read.progressValue} of $pageCount'
      : fraction != null
      ? '${(fraction * 100).round()}%'
      : 'Add the page count';

  return (label: label, fraction: fraction);
}

// The first tab: a greeting, this year's numbers, books in progress,
// friends' recent activity and the user's libraries. Every section shows
// with its own empty state, except Friends, which hides when empty.
class HomeScreen extends ConsumerWidget {
  final VoidCallback onOpenLibraries; // jumps to the Library tab

  const HomeScreen({super.key, required this.onOpenLibraries});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // Saves opening the book just to type the page reached today
  Future<void> _updatePage(
    BuildContext context,
    WidgetRef ref,
    ReadingLogModel log,
    String uid,
  ) async {
    final key = log.id;
    final pageCount = log.pageCount ?? 0;
    if (key == null || pageCount <= 0) return;

    // Old percent progress is turned into a page, as on the book page
    final read = log.latestRead;
    final current = read == null
        ? 0
        : read.progressUnit == ProgressUnit.percent
        ? (read.progressValue * pageCount / 100).round()
        : read.progressValue;

    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(readingLogRepositoryProvider);
    final value = await showNumberDialog(
      context,
      title: 'Current page',
      initial: current.clamp(0, pageCount),
      min: 0,
      max: pageCount,
    );
    if (value == null) return;

    try {
      await repository.updateProgess(value, ProgressUnit.pages, key, uid);
    } catch (e) {
      debugPrint('updateProgess failed: $e');
      messenger.showError("Couldn't save progress, check your connection");
    }
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
    final feed = ref.watch(friendsFeedProvider);

    // Opens a book's reading page; null when the log has no id yet
    VoidCallback? open(ReadingLogModel log) {
      final key = log.id;
      if (key == null) return null;
      return () => _push(context, ReadingLogDetailScreen(readingKey: key));
    }

    return Scaffold(
      // No app bar: the header runs up behind the status bar
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark, // dark status bar icons
        child: Stack(
          children: [
            ListView(
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
                    onPressed: () =>
                        _push(context, const NotificationsScreen()),
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
                        onSeeAll: () =>
                            _push(context, const ReadingLogsScreen()),
                      ),
                      const SizedBox(height: 8),
                      if (inProgress.isEmpty)
                        _EmptyReadingCard(onOpenLibraries: onOpenLibraries)
                      else ...[
                        // The book read most recently gets the big card
                        _HeroReadingCard(
                          log: inProgress.first,
                          onTap: open(inProgress.first),
                          onUpdatePage: () =>
                              _updatePage(context, ref, inProgress.first, uid),
                        ),
                        if (inProgress.length > 1) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 128,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              // Lets the cards scroll to the screen edge
                              clipBehavior: Clip.none,
                              itemCount: inProgress.length - 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final log = inProgress[i + 1];
                                return _ContinueCard(
                                  log: log,
                                  onTap: open(log),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),

                      // Hidden until there's something to show: no friends yet,
                      // or still loading
                      if (feed.isNotEmpty) ...[
                        _SectionTitle(
                          icon: Icons.people_alt_rounded,
                          title: 'Friends',
                          onSeeAll: () => _push(context, const FriendsScreen()),
                        ),
                        const SizedBox(height: 8),
                        _FriendsCard(
                          items: feed,
                          onOpen: (item) => _push(
                            context,
                            FriendScreen(
                              friendship: item.friendship,
                              myUid: uid,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

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
                              onTap: () => _push(
                                context,
                                CreateLibraryScreen(userId: uid),
                              ),
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
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
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
            // Solid strip over the status bar so scrolled content doesn't
            // run under the clock; white like the top bar on every other page
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: const ColoredBox(color: AppColors.background),
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
      // Plain white, like the top bar on every other page
      color: AppColors.background,
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

    // Solid blue, the Stats colour on Profile
    return Material(
      color: AppColors.accent,
      clipBehavior: Clip.antiAlias, // keeps the ripple inside the corners
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your $year',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Not a button: the whole card already opens stats
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.onPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _BigNumber(
                    value: '${stats.finished}',
                    label: 'books finished',
                  ),
                  _BigNumber(
                    value: _thousands(stats.pagesRead),
                    label: 'pages read',
                  ),
                  _BigNumber(value: '$readingNow', label: 'reading now'),
                ],
              ),
              // Month bars only once a book is finished
              if (stats.finished > 0) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 12; i++)
                        Expanded(
                          child: Container(
                            height: counts[i] == 0 ? 3 : 40 * counts[i] / most,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              // This month is solid white, the rest faded
                              color: AppColors.onPrimary.withValues(
                                alpha: counts[i] == 0
                                    ? 0.25
                                    : i + 1 == currentMonth
                                    ? 1
                                    : 0.7,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Month initials so the bars read as a year, not a loader
                Row(
                  children: [
                    for (var i = 0; i < 12; i++)
                      Expanded(
                        child: Text(
                          'JFMAMJJASOND'[i],
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.onPrimary.withValues(
                              alpha: i + 1 == currentMonth ? 1 : 0.7,
                            ),
                            fontWeight: i + 1 == currentMonth
                                ? FontWeight.w700
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// One stat on the blue card: large white number over a small label.
// Takes a third of the row.
class _BigNumber extends StatelessWidget {
  final String value;
  final String label;

  const _BigNumber({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // GoogleFonts.dmSans so the w700 font file loads
            style: GoogleFonts.dmSans(
              textStyle: textTheme.headlineSmall,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
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

// The book read most recently, large on a soft green card: big cover,
// title, progress, and a button to type today's page without opening it
class _HeroReadingCard extends StatelessWidget {
  final ReadingLogModel log;
  final VoidCallback? onTap;
  final VoidCallback onUpdatePage;

  const _HeroReadingCard({
    required this.log,
    required this.onTap,
    required this.onUpdatePage,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (:label, :fraction) = _progressOf(log);
    final paused = log.status == BookStatus.paused;
    // Without a page count there's nothing to type a page against, so the
    // button opens the book page where the count is added
    final hasPages = (log.pageCount ?? 0) > 0;

    return Material(
      color: AppColors.primarySoft,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(url: log.coverUrl, width: 96, height: 144),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 16),
                    Text(
                      paused ? 'Paused · $label' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        color: paused
                            ? AppColors.warning
                            : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: fraction ?? 0,
                        minHeight: 8,
                        color: paused ? AppColors.warning : AppColors.primary,
                        backgroundColor: AppColors.background,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: hasPages ? onUpdatePage : onTap,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(
                        hasPages ? Icons.edit_note_rounded : Icons.add_rounded,
                        size: 18,
                      ),
                      label: Text(hasPages ? 'Update page' : 'Add page count'),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final (label: progressLabel, :fraction) = _progressOf(log);
    final paused = log.status == BookStatus.paused;

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

// Friends' newest activity in one bordered card, a row per item
class _FriendsCard extends StatelessWidget {
  final List<FeedItem> items;
  final ValueChanged<FeedItem> onOpen;

  const _FriendsCard({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _FeedRow(item: items[i], onTap: () => onOpen(items[i])),
          ],
        ],
      ),
    );
  }
}

// "@sam finished Dune" with the date under it and the cover on the right
class _FeedRow extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;

  const _FeedRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bold = textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final user = TextSpan(text: '@${item.username}', style: bold);
    final book = TextSpan(text: item.title, style: bold);

    final spans = switch (item.type) {
      FeedItemType.started => [user, const TextSpan(text: ' started '), book],
      FeedItemType.finished => [user, const TextSpan(text: ' finished '), book],
      FeedItemType.becameFriends => [
        const TextSpan(text: 'You and '),
        user,
        const TextSpan(text: ' became friends'),
      ],
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Clay avatar from the uid, so the card needs no profile reads
            ClayAvatar(seed: item.friendUid, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: spans),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  Text(
                    dayMonth(item.at),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (item.type != FeedItemType.becameFriends) ...[
              const SizedBox(width: 12),
              _Cover(url: item.coverUrl, width: 32, height: 48),
            ],
          ],
        ),
      ),
    );
  }
}

// One library as a photo card: the banner fills it, and the name and book
// count sit in white over a dark fade at the bottom
class _LibraryTile extends StatelessWidget {
  final LibraryModel library;
  final VoidCallback onTap;

  const _LibraryTile({required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = library.bookCount;

    return SizedBox(
      width: 220,
      child: Material(
        color: AppColors.surfaceMuted,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        // Ink.image keeps the ripple visible on top of the photo
        child: Ink.image(
          image: library.bannerImage,
          fit: BoxFit.cover,
          child: InkWell(
            onTap: onTap,
            child: Container(
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1],
                  colors: [
                    AppColors.text.withValues(alpha: 0),
                    AppColors.text.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    library.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    count == 1 ? '1 book' : '$count books',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Always last in the library row: a soft green card that opens
// Create library
class _NewLibraryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _NewLibraryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Material(
        color: AppColors.primarySoft,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'New library',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.primaryDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
