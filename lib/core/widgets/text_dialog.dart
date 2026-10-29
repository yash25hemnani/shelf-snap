import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';

// Asks for one line of text; null when cancelled. The text comes back
// trimmed, so an empty string means the user cleared the field.
// [suggestions] are chips that fill the field with a starting text.
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  List<String> suggestions = const [],
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(
      title: title,
      initial: initial,
      hint: hint,
      suggestions: suggestions,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  final String title;
  final String? initial;
  final String? hint;
  final List<String> suggestions;

  const _TextDialog({
    required this.title,
    this.initial,
    this.hint,
    required this.suggestions,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  // Fills the field with "Bought " and puts the cursor at the end,
  // so the user can carry on typing "at Crossword"
  void _useSuggestion(String suggestion) {
    final text = '$suggestion ';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: textTheme.titleLarge),
            const SizedBox(height: 16),
            if (widget.suggestions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in widget.suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => _useSuggestion(suggestion),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: widget.hint),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    // Grey, so Save is the one that stands out
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
