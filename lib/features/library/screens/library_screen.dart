import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final List<String> libraries = [
    'Flutter',
    'Riverpod',
    'Dart',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Libraries"),
      ),
      body: ListView.builder(
        itemCount: libraries.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(libraries[index]),
          );
        },
      ),
    );
  }
}