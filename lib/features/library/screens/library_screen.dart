import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/invites/providers/invite_provider.dart';
import 'package:shelf_snap/features/invites/screens/notifications_screen.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/library_detail_screen.dart';
import 'package:shelf_snap/features/library/screens/create_library_screen.dart';
import 'package:shelf_snap/features/library/widgets/library_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.uid;

    // AuthGate handles login; build must not navigate
    if (userId == null || userId.isEmpty) {
      return const Scaffold(body: Center(child: Text("Not signed in")));
    }

    final librariesAsync = ref.watch(userLibrariesProvider(userId));
    final inviteCount =
        ref.watch(incomingInvitesProvider(userId)).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleTextStyle: Theme.of(context).textTheme.headlineMedium,
        title: const Text("Libraries"),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            // The badge shows the number of pending invites
            icon: Badge.count(
              count: inviteCount,
              isLabelVisible: inviteCount > 0,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: librariesAsync.when(
        data: (items) {
          final visible = items.where(_matches).toList();

          return Column(
            children: [
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (text) => setState(() => _query = text),
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search libraries',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          items.isEmpty
                              ? 'No libraries yet. Tap + to create one!'
                              : 'No libraries match your search',
                        ),
                      )
                    : ListView.builder(
                        // Extra bottom space so the FAB doesn't cover the last card
                        padding: const EdgeInsets.only(bottom: 88),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final library = visible[index];
                          return LibraryCard(
                            library: library,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LibraryDetailScreen(library: library),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        error: (err, stack) => Center(child: Text("Error: $err")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateLibraryScreen(userId: userId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  // True when every typed word appears in the library's name or description
  bool _matches(LibraryModel library) {
    final words = removeDiacritics(
      _query.toLowerCase(),
    ).split(' ').where((w) => w.isNotEmpty);
    final text = removeDiacritics(
      '${library.name} ${library.description ?? ''}'.toLowerCase(),
    );
    return words.every(text.contains);
  }
}
