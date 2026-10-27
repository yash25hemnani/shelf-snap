import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

class CreateLibraryForm extends ConsumerStatefulWidget {
  final String userId;
  final LibraryModel? library; // set = editing this library
  const CreateLibraryForm({super.key, required this.userId, this.library});

  @override
  ConsumerState<CreateLibraryForm> createState() => _CreateLibraryFormState();
}

class _CreateLibraryFormState extends ConsumerState<CreateLibraryForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // True while the save is in progress; disables the button
  bool _isSaving = false;

  String _banner = AppColors.defaultBanner; // key in AppColors.libraryBanners

  bool get _isEditing => widget.library != null;

  @override
  void initState() {
    super.initState();
    final library = widget.library;

    if (library != null) {
      _nameController.text = library.name;
      _descController.text = library.description ?? '';
      _banner = library.banner;
    }
  }

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
      banner: _banner,
      createdAt: now,
      updatedAt: now,
    );

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await repository.updateLibrary(
          LibraryModel(
            id: widget.library!.id,
            name: name,
            description: desc.isEmpty ? null : desc,
            ownerId: widget.library!.ownerId,
            banner: _banner,
            createdAt: widget.library!.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        await repository.createLibrary(library);
      }

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
            Text(
              _isEditing ? "Edit Library" : "New library",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Preview of the banner the library will get
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: AssetImage(AppColors.libraryBanners[_banner]!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in AppColors.libraryBanners.entries)
                  GestureDetector(
                    onTap: () => setState(() => _banner = entry.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 64,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: AssetImage(entry.value),
                          fit: BoxFit.cover,
                        ),
                        // Ring around the selected banner
                        border: Border.all(
                          color: entry.key == _banner
                              ? AppColors.text
                              : AppColors.background,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description (optional)",
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _onSubmit,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Create library"),
            ),
          ],
        ),
      ),
    );
  }
}
