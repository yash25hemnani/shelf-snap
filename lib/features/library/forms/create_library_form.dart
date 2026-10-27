import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
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
      ScaffoldMessenger.of(context).showError("Couldn't save library");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full-width preview of the chosen banner
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: AssetImage(AppColors.libraryBanners[_banner]!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Banner options, centred under the preview
                  Wrap(
                    alignment: WrapAlignment.center,
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
                                    ? AppColors.primary
                                    : AppColors.background,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _FieldLabel('Library Name'),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Book Buddies',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  const _FieldLabel('Description (optional)'),
                  TextFormField(
                    controller: _descController,
                    maxLength: 200,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'A shared space for book lovers…',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stays at the bottom, above the keyboard
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: _isSaving ? null : _onSubmit,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Create Library'),
            ),
          ),
        ],
      ),
    );
  }
}

// Bold label shown above a field
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
