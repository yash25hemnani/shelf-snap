import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';

// Add or remove the authors, titles and words to look out for. Each change
// saves straight away; matching books get a star in Discovered.
class DiscoverKeywordsSheet extends ConsumerStatefulWidget {
  const DiscoverKeywordsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const DiscoverKeywordsSheet(),
    );
  }

  @override
  ConsumerState<DiscoverKeywordsSheet> createState() =>
      _DiscoverKeywordsSheetState();
}

class _DiscoverKeywordsSheetState extends ConsumerState<DiscoverKeywordsSheet> {
  final _controller = TextEditingController();

  DiscoverSettingsModel get _settings =>
      ref.read(discoverSettingsProvider).valueOrNull ??
      const DiscoverSettingsModel();

  // Not awaited, like the genre and place saves, so it works offline.
  // Firestore's local copy updates at once, so the chips redraw straight away.
  void _save(DiscoverSettingsModel next) {
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      ref.read(discoverRepositoryProvider).saveSettings(userId, next).catchError(
        (Object e) {
          debugPrint('saveSettings failed: $e');
          messenger.showError("Couldn't save your keywords");
        },
      ),
    );
  }

  void _add() {
    final settings = _settings;
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    if (settings.keywords.length >= DiscoverSettingsModel.maxKeywords) {
      ScaffoldMessenger.of(context).showError(
        'You can keep up to ${DiscoverSettingsModel.maxKeywords} keywords',
      );
      return;
    }

    final next = settings.withKeyword(text);
    _controller.clear();
    // Same list back means it was already there
    if (identical(next, settings)) return;
    _save(next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final keywords =
        ref.watch(discoverSettingsProvider).valueOrNull?.keywords ?? const [];

    return Padding(
      // Lifts the sheet above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your keywords', style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Authors, titles or words to look out for. Books that match '
                'get a star and go to the top of Discovered.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: keywords.isEmpty,
                maxLength: DiscoverSettingsModel.maxKeywordLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Murakami, Dune, dragons',
                  prefixIcon: const Icon(Icons.star_outline_rounded),
                  counterText: '',
                  suffixIcon: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => IconButton(
                      tooltip: 'Add',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _controller.text.trim().isEmpty ? null : _add,
                    ),
                  ),
                ),
                // Keeps the keyboard up so several can be added in a row
                onSubmitted: (_) => _add(),
                onEditingComplete: () {},
              ),
              const SizedBox(height: 16),
              if (keywords.isEmpty)
                Text(
                  'No keywords yet',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.hint),
                )
              else ...[
                Text(
                  '${keywords.length} of ${DiscoverSettingsModel.maxKeywords}',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.hint,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final keyword in keywords)
                          InputChip(
                            label: Text(keyword),
                            onDeleted: () =>
                                _save(_settings.withoutKeyword(keyword)),
                            deleteButtonTooltipMessage: 'Remove',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
