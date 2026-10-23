import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/library_detail_screen.dart';
import 'package:shelf_snap/features/library/sheets/create_library_sheet.dart';
import 'package:shelf_snap/features/library/widgets/library_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.uid;

    // AuthGate handles login; build must not navigate
    if (userId == null || userId.isEmpty) {
      return const Scaffold(body: Center(child: Text("Not signed in")));
    }

    final librariesAsync = ref.watch(userLibrariesProvider(userId));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        titleTextStyle: Theme.of(context).textTheme.headlineMedium,
        title: const Text("Libraries"),
      ),
      body: librariesAsync.when(
        data: (items) => ListView.builder(
          // Extra bottom space so the FAB doesn't cover the last card
          padding: const EdgeInsets.only(top: 8, bottom: 88),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final library = items[index];
            return LibraryCard(
              library: library,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LibraryDetailScreen(library: library),
                ),
              ),
            );
          },
        ),
        error: (err, stack) => Center(child: Text("Error: $err")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CreateLibrarySheet.show(context, userId: userId),
        child: const Icon(Icons.add),
      ),
    );
  }
}
