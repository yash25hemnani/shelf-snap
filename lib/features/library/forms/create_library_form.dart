import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/config/api_config.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';
import 'package:shelf_snap/features/library/providers/library_provider.dart';

class CreateLibraryForm extends ConsumerStatefulWidget {
  final String userId;
  final LibraryModel? library; // set = editing this library
  final LibraryAccess initialAccess; // used for new libraries only
  const CreateLibraryForm({
    super.key,
    required this.userId,
    this.library,
    this.initialAccess = LibraryAccess.private,
  });

  @override
  ConsumerState<CreateLibraryForm> createState() => _CreateLibraryFormState();
}

class _CreateLibraryFormState extends ConsumerState<CreateLibraryForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _handleController = TextEditingController();

  // False until the user types a handle; until then it follows the name
  bool _handleEdited = false;
  // Set when the handle turns out to be taken, shown under the field
  String? _handleError;

  // True while the save is in progress; disables the button
  bool _isSaving = false;

  String _banner = AppColors.defaultBanner; // key in AppColors.libraryBanners

  late LibraryAccess _access;

  bool get _isEditing => widget.library != null;

  @override
  void initState() {
    super.initState();
    final library = widget.library;
    _access = library?.access ?? widget.initialAccess;

    if (library != null) {
      _nameController.text = library.name;
      _descController.text = library.description ?? '';
      _banner = library.banner;
      _handleController.text = library.handle ?? '';
      _handleEdited = library.handle != null;
    }
  }

  // Keeps a suggested handle in step with the name until the user edits it
  void _onNameChanged(String name) {
    if (_handleEdited) return;
    _handleController.text = LibraryModel.slugify(name);
  }

  String? _validateHandle(String? value) {
    final handle = value?.trim() ?? '';
    if (handle.isEmpty) return null; // optional
    if (!LibraryModel.handlePattern.hasMatch(handle)) {
      return '3-30 lowercase letters, numbers or hyphens';
    }
    if (LibraryModel.reservedHandles.contains(handle)) {
      return 'That one is reserved, try another';
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    setState(() => _handleError = null);
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(libraryRepositoryProvider);
    // Captured before the await, so the snackbar works after it
    final messenger = ScaffoldMessenger.of(context);

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final now = DateTime.now();
    final oldHandle = widget.library?.handle;
    final typed = _handleController.text.trim();
    // Private libraries keep any handle they had, for when they go public
    final handle = _access == LibraryAccess.public
        ? (typed.isEmpty ? null : typed)
        : oldHandle;

    final library = LibraryModel(
      name: name,
      description: desc.isEmpty ? null : desc,
      ownerId: widget.userId,
      banner: _banner,
      access: _access,
      handle: handle,
      createdAt: now,
      updatedAt: now,
    );

    setState(() => _isSaving = true);

    try {
      // Checked here so the field can say so; the rules still stop a race
      if (handle != null &&
          handle != oldHandle &&
          await repository.isHandleTaken(
            handle,
            libraryId: widget.library?.id,
          )) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _handleError = 'Another library already uses this';
        });
        return;
      }

      if (_isEditing) {
        await repository.updateLibrary(
          LibraryModel(
            id: widget.library!.id,
            name: name,
            description: desc.isEmpty ? null : desc,
            ownerId: widget.library!.ownerId,
            banner: _banner,
            access: _access,
            handle: handle,
            createdAt: widget.library!.createdAt,
            updatedAt: DateTime.now(),
          ),
          oldHandle: oldHandle,
        );
      } else {
        await repository.createLibrary(library);
      }

      // The user may have left while we were waiting
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Save library failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showError("Couldn't save library");
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
                    onChanged: _onNameChanged,
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
                  const SizedBox(height: 20),

                  const _FieldLabel('Who can find it'),
                  SegmentedButton<LibraryAccess>(
                    segments: const [
                      ButtonSegment(
                        value: LibraryAccess.private,
                        label: Text('Private'),
                        icon: Icon(Icons.lock_outline_rounded),
                      ),
                      ButtonSegment(
                        value: LibraryAccess.public,
                        label: Text('Public'),
                        icon: Icon(Icons.public_rounded),
                      ),
                    ],
                    selected: {_access},
                    onSelectionChanged: (selection) =>
                        setState(() => _access = selection.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _access == LibraryAccess.public
                        ? 'Anyone can find this library and see its public books'
                        : 'Only people you invite can see it',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  // Only public libraries get a web page
                  if (_access == LibraryAccess.public) ...[
                    const SizedBox(height: 20),
                    const _FieldLabel('Web address (optional)'),
                    TextFormField(
                      controller: _handleController,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 30,
                      textInputAction: TextInputAction.done,
                      // Lowercase as you type; spaces become hyphens
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (_, value) => value.copyWith(
                            text: value.text.toLowerCase().replaceAll(' ', '-'),
                          ),
                        ),
                        FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]')),
                      ],
                      onChanged: (_) => setState(() {
                        _handleEdited = true;
                        _handleError = null;
                      }),
                      decoration: InputDecoration(
                        prefixText: '/l/',
                        hintText: 'book-buddies',
                        // Full address so owners know where it'll live
                        helperText:
                            "Web catalog at ${ApiConfig.baseUrl.replaceFirst(RegExp(r'^https?://'), '')}/l/…",
                        errorText: _handleError,
                      ),
                      validator: _validateHandle,
                    ),
                  ],
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
