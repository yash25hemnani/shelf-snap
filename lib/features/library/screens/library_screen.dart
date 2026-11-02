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

  void _createLibrary(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateLibraryScreen(userId: userId)),
    );
  }

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
                child: visible.isEmpty && _query.isNotEmpty
                    ? const Center(
                        child: Text('No libraries match your search'),
                      )
                    : ListView.builder(
                        // Extra bottom space so the last card clears the navbar
                        padding: const EdgeInsets.only(bottom: 32),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        // The New library row is last, hidden while searching
                        itemCount: visible.length + (_query.isEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == visible.length) {
                            return _NewLibraryRow(
                              onTap: () => _createLibrary(userId),
                            );
                          }
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

// Last row of the list, in place of a floating + that sat on top of the
// Scan button: a soft green card with the same margins as a library card
class _NewLibraryRow extends StatelessWidget {
  final VoidCallback onTap;

  const _NewLibraryRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.primarySoft,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Same size as a library thumbnail so the rows line up
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New library',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.primaryDark),
                      ),
                      Text(
                        'A shelf, a room or one you share',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
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
