import 'package:flutter/material.dart';

Future<String?> showReviewSheet(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ReviewSheet(current: current),
  );
}

class _ReviewSheet extends StatefulWidget {
  final String? current;

  const _ReviewSheet({this.current});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 6,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Write your thoughts about this book...',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, _controller.text.trim()),
                child: const Text('Save review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
