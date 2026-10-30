import 'package:flutter/material.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/languages.dart';

// Asks for a language from [languageNames]; null when dismissed.
// An empty string means the user picked "Not set".
Future<String?> showLanguageSheet(
  BuildContext context, {
  required String title,
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LanguageSheet(title: title, current: current),
  );
}

class _LanguageSheet extends StatefulWidget {
  final String title;
  final String? current;

  const _LanguageSheet({required this.title, this.current});

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  var _query = '';

  // Matches the name, or the exact code: "mar" and "mr" both find Marathi
  List<MapEntry<String, String>> get _matches {
    final q = _query.trim().toLowerCase();
    return languageNames.entries
        .where(
          (e) => q.isEmpty || e.value.toLowerCase().contains(q) || e.key == q,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final matches = _matches;

    // Tall sheet; the bottom inset shrinks the list when the keyboard opens
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search languages',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (text) => setState(() => _query = text),
                  ),
                ],
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No languages match',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        // Only worth offering when something is set
                        if (_query.isEmpty && widget.current != null)
                          ListTile(
                            title: const Text(
                              'Not set',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            onTap: () => Navigator.pop(context, ''),
                          ),
                        for (final MapEntry(:key, :value) in matches)
                          ListTile(
                            title: Text(value),
                            trailing: key == widget.current
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, key),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
