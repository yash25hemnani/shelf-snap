import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/core/widgets/confirm_dialog.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/sheets/invite_sheet.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/create_library_screen.dart';
import 'package:shelf_snap/features/library/sheets/add_book_sheet.dart';
import 'package:shelf_snap/features/library/widgets/books_tab.dart';
import 'package:shelf_snap/features/library/widgets/member_avatars.dart';
import 'package:shelf_snap/features/library/widgets/members_tab.dart';
import 'package:shelf_snap/features/profile/providers/user_provider.dart';

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

  Future<void> _onAction(
    _LibraryAction action,
    LibraryModel library,
    bool isOwner,
  ) async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    if (action == _LibraryAction.addBook) {
      AddBookSheet.show(context, libraryId: library.id!);
      return;
    }

    if (action == _LibraryAction.edit) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateLibraryScreen(userId: userId, library: library),
        ),
      );
      return;
    }

    final isDelete = action == _LibraryAction.delete;
    final confirmed = await showConfirmDialog(
      context,
      icon: isDelete ? Icons.delete_outline_rounded : Icons.logout_rounded,
      title: isDelete ? 'Delete ${library.name}?' : 'Leave ${library.name}?',
      message: isDelete
          ? 'All its books are deleted for every member. This cannot be undone.'
          : "You'll lose access to this library's books until you're invited again.",
      confirmLabel: isDelete ? 'Delete' : 'Leave',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    // Back to the list first, since this page loses access once it's done
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(libraryRepositoryProvider);
    Navigator.pop(context);

    try {
      if (isDelete) {
        await repository.deleteLibrary(library.id!);
        messenger.showMessage('Deleted ${library.name}');
      } else {
        await repository.removeMember(library.id!, userId);
        messenger.showMessage('Left ${library.name}');
      }
    } catch (e) {
      messenger.showError(
        isDelete ? "Couldn't delete library" : "Couldn't leave library",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    // Live copy of the library, or the one passed in until it loads
    final live = ref.watch(libraryProvider(library.id!)).valueOrNull ?? library;
    final uid = AuthService().currentUser?.uid;
    final isOwner = live.ownerId == uid;
    final canEdit = live.canEdit(uid);
    // False for someone looking at a public library they aren't in
    final isMember = live.members.contains(uid);

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
                        // Visitors have nothing to edit or leave
                        actions: [
                          if (isMember)
                            PopupMenuButton<_LibraryAction>(
                              tooltip: 'Library options',
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (action) =>
                                  _onAction(action, live, isOwner),
                              // Editors can type a book in; the owner edits or
                              // deletes; everyone else can only leave
                              itemBuilder: (_) => [
                                if (canEdit)
                                  const PopupMenuItem(
                                    value: _LibraryAction.addBook,
                                    child: Text('Add a book by hand'),
                                  ),
                                if (isOwner) ...const [
                                  PopupMenuItem(
                                    value: _LibraryAction.edit,
                                    child: Text('Edit library'),
                                  ),
                                  PopupMenuItem(
                                    value: _LibraryAction.delete,
                                    child: Text(
                                      'Delete library',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ] else
                                  const PopupMenuItem(
                                    value: _LibraryAction.leave,
                                    child: Text(
                                      'Leave library',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ),
                              ],
                            ),
                        ],
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
                                    )
                                  // Visitors to a public library can ask in
                                  else if (!isMember && live.isPublic)
                                    _JoinButton(library: live),
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

enum _LibraryAction { addBook, edit, delete, leave }

// Request to join a public library, or cancel a request that's waiting.
// Becomes the member view once the owner approves.
class _JoinButton extends ConsumerStatefulWidget {
  final LibraryModel library;

  const _JoinButton({required this.library});

  @override
  ConsumerState<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends ConsumerState<_JoinButton> {
  bool _busy = false; // true while the request or cancel is in flight

  Future<void> _request() async {
    final uid = AuthService().currentUser?.uid;
    final username = uid == null
        ? null
        : ref.read(userProfileProvider(uid)).valueOrNull?.username;
    final messenger = ScaffoldMessenger.of(context);
    // Rules check the username against the profile, so wait for it
    if (uid == null || username == null || username.isEmpty) {
      messenger.showError('Set a username before asking to join');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .requestToJoin(widget.library, uid, username);
      messenger.showMessage('Request sent to the owner');
    } catch (e) {
      debugPrint('Request to join failed: $e');
      messenger.showError("Couldn't send request");
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.close_rounded,
      title: 'Cancel request?',
      message: "The owner won't see your request to join anymore.",
      confirmLabel: 'Cancel request',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .deleteJoinRequest(widget.library.id!, uid);
      messenger.showMessage('Request cancelled');
    } catch (e) {
      debugPrint('Cancel join request failed: $e');
      messenger.showError("Couldn't cancel request");
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final requested = ref.watch(hasRequestedToJoinProvider(widget.library.id!));
    // Watched so the username is loaded by the time the button is tapped
    final uid = AuthService().currentUser?.uid;
    if (uid != null) ref.watch(userProfileProvider(uid));
    final textTheme = Theme.of(context).textTheme;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
    );

    // Nothing until we know, so the button doesn't flip on open
    if (!requested.hasValue) return const SizedBox.shrink();

    if (requested.value!) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : _cancel,
        icon: const Icon(Icons.schedule_rounded, size: 18),
        label: const Text('Requested'),
        style: style,
      );
    }

    return FilledButton.icon(
      onPressed: _busy ? null : _request,
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text('Request to join'),
      style: style,
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
