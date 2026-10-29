import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Asks for a whole number from [min] to [max]; null when cancelled.
// Progress passes min 0; a page count keeps the default of 1.
Future<int?> showNumberDialog(
  BuildContext context, {
  required String title,
  int? initial,
  int min = 1,
  int? max,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) =>
        _NumberDialog(title: title, initial: initial, min: min, max: max),
  );
}

class _NumberDialog extends StatefulWidget {
  final String title;
  final int? initial;
  final int min;
  final int? max;

  const _NumberDialog({
    required this.title,
    this.initial,
    required this.min,
    this.max,
  });

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final result = int.tryParse(_controller.text);

    if (result == null || result < widget.min) {
      setState(() => _error = 'Enter a number');
      return;
    }

    // Local copy, so Dart knows it's non-null inside the check
    final max = widget.max;
    if (max != null && result > max) {
      setState(() => _error = 'Max is $max');
      return;
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
