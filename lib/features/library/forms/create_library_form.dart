import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

class CreateLibraryForm extends ConsumerStatefulWidget {
  final String userId;
  const CreateLibraryForm({super.key, required this.userId});

  @override
  ConsumerState<CreateLibraryForm> createState() => _CreateLibraryFormState();
}

class _CreateLibraryFormState extends ConsumerState<CreateLibraryForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // True while the save is in progress; disables the button
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(libraryRepositoryProvider);

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final now = DateTime.now();

    final library = LibraryModel(
      name: name,
      description: desc.isEmpty ? null : desc,
      ownerId: widget.userId,
      createdAt: now,
      updatedAt: now,
    );

    setState(() => _isSaving = true);

    try {
      await repository.createLibrary(library);

      // The user may have left while we were waiting
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not create library: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("New library", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: "Name"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Enter a name";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: "Description (optional)",
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSaving ? null : _onSubmit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Create"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
