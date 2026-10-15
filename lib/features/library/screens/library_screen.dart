import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/auth/services/auth_service.dart';
import 'package:shelf_snap/features/library/dialogs/create_library_dialog.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';
import 'package:shelf_snap/features/library/screens/library_detail_screen.dart';
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
      appBar: AppBar(title: const Text("Libraries")),
      body: librariesAsync.when(
        data: (items) => ListView.builder(
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
        onPressed: () => showDialog(
          context: context,
          builder: (_) => CreateLibraryDialog(userId: userId),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
