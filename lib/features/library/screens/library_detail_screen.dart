import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/sheets/invite_sheet.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/widgets/books_tab.dart';
import 'package:shelf_snap/features/library/widgets/member_avatars.dart';
import 'package:shelf_snap/features/library/widgets/members_tab.dart';

class LibraryDetailScreen extends ConsumerStatefulWidget {
  final LibraryModel library;

  const LibraryDetailScreen({super.key, required this.library});

  @override
  ConsumerState<LibraryDetailScreen> createState() =>
      _LibraryDetailScreenState();
}

class _LibraryDetailScreenState extends ConsumerState<LibraryDetailScreen> {
  static const _bannerHeight = 140.0;

  static const _tabBar = TabBar(
    labelColor: AppColors.primary,
    unselectedLabelColor: AppColors.textSecondary,
    indicatorColor: AppColors.primary,
    indicatorSize: TabBarIndicatorSize.tab,
    dividerColor: AppColors.border,
    tabs: [
      Tab(text: 'Books'),
      Tab(text: 'Members'),
    ],
  );

  final _scroll = ScrollController();

  // True once the banner has collapsed into the toolbar
  bool _collapsed = false;
  // True once the name under the banner has scrolled under the toolbar
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  // SliverAppBar ignores the theme's toolbar height, so it's passed in
  double get _toolbarHeight =>
      Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;

  // Rebuilds only when the scroll crosses one of the two points
  void _onScroll() {
    final collapsePoint = _bannerHeight - _toolbarHeight;
    final collapsed = _scroll.offset > collapsePoint;
    final showTitle = _scroll.offset > collapsePoint + 30;

    if (collapsed != _collapsed || showTitle != _showTitle) {
      setState(() {
        _collapsed = collapsed;
        _showTitle = showTitle;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    // Live copy of the library, or the one passed in until it loads
    final live = ref.watch(libraryProvider(library.id!)).valueOrNull ?? library;
    final isOwner = live.ownerId == AuthService().currentUser?.uid;

    // Owner's name, once the member profiles have loaded
    final members =
        ref.watch(libraryMembersProvider(library.id!)).valueOrNull ?? [];
    final owner = members.where((m) => m.uid == live.ownerId).firstOrNull;
    final ownerName = isOwner ? 'you' : owner?.name;

    final memberCount = live.members.length;
    final textTheme = Theme.of(context).textTheme;

    // Status bar + collapsed toolbar + tabs, the part that stays on screen
    final pinnedHeight =
        MediaQuery.paddingOf(context).top +
        _toolbarHeight +
        _tabBar.preferredSize.height;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        // No stretch effect at the scroll edges, which made the header bounce
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: NestedScrollView(
            controller: _scroll,
            headerSliverBuilder: (context, _) => [
              // Reports how tall the pinned toolbar and tabs are, so the
              // tab content can start below them instead of scrolling under
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: _PinnedHeight(
                  height: pinnedHeight,
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: _bannerHeight,
                        toolbarHeight: _toolbarHeight,
                        // White icons over the photo, a plain bar with the name once collapsed
                        foregroundColor: _collapsed
                            ? AppColors.text
                            : AppColors.onPrimary,
                        backgroundColor: AppColors.background,
                        // Always laid out and only faded, so the toolbar never shifts
                        title: AnimatedOpacity(
                          opacity: _showTitle ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Text(live.name),
                        ),
                        // Title sits right after the back arrow
                        titleSpacing: 0,
                        titleTextStyle: textTheme.headlineSmall?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Image(
                            image: live.bannerImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Library name and meta under the banner
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(live.name, style: textTheme.titleLarge),
                              Text(
                                '$memberCount ${memberCount == 1 ? 'member' : 'members'}'
                                ' · ${live.bookCount} ${live.bookCount == 1 ? 'book' : 'books'}'
                                '${ownerName != null ? ' · Owned by $ownerName' : ''}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  MemberAvatars(members: members, size: 42),
                                  const Spacer(),
                                  // Only the owner can invite people
                                  if (isOwner)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          InviteSheet.show(context, live),
                                      icon: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Invite Members'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 36),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        textStyle: textTheme.labelLarge,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      // Stays under the toolbar while the tabs scroll
                      const SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabBarHeader(_tabBar),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Pushed down by the pinned header's height from the first frame,
            // so the search box and the first row stay visible under the tabs
            body: Padding(
              padding: EdgeInsets.only(top: pinnedHeight),
              child: TabBarView(
                children: [
                  BooksTab(libraryId: library.id!),
                  MembersTab(library: live),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Tells NestedScrollView how much of the header stays pinned, which
// SliverMainAxisGroup doesn't report on its own
class _PinnedHeight extends SingleChildRenderObjectWidget {
  final double height;

  const _PinnedHeight({required this.height, required Widget sliver})
    : super(child: sliver);

  @override
  _RenderPinnedHeight createRenderObject(BuildContext context) =>
      _RenderPinnedHeight(height);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPinnedHeight renderObject,
  ) {
    renderObject.height = height;
  }
}

class _RenderPinnedHeight extends RenderProxySliver {
  _RenderPinnedHeight(this._height);

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    geometry = child!.geometry!.copyWith(maxScrollObstructionExtent: _height);
  }
}

// Fixed-height header that holds the Books / Members tab bar
class _TabBarHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabBarHeader(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: AppColors.background, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarHeader oldDelegate) => oldDelegate.tabBar != tabBar;
}
