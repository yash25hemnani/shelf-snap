import 'package:flutter/material.dart';
import 'package:shelf_snap/features/library/models/library_model.dart';

/// Library dropdown with a Save button beside it.
/// [onSave] null disables the button; [isSaving] shows a spinner in it.
class LibraryPickerBar extends StatelessWidget {
  final List<LibraryModel> libraries;
  final String? selectedId;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSave;
  final bool isSaving;

  const LibraryPickerBar({
    super.key,
    required this.libraries,
    required this.selectedId,
    required this.onChanged,
    required this.onSave,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            // Rebuilds the field when the selection is set from outside
            key: ValueKey(selectedId),
            initialValue: selectedId,
            isExpanded: true,
            hint: const Text('Choose a library'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.local_library_outlined),
            ),
            items: [
              for (final lib in libraries)
                DropdownMenuItem(
                  value: lib.id,
                  child: Text(lib.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: isSaving
                ? null
                : (id) {
                    if (id != null) onChanged(id);
                  },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: isSaving ? null : onSave,
          child: isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
