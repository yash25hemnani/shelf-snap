import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/theme/app_colors.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';

// Sets the place that every Discover scan is tagged with until it's
// changed: type a new one, tap a recent one, or clear it
class PlaceSheet extends ConsumerStatefulWidget {
  final DiscoverSettingsModel settings;

  const PlaceSheet({super.key, required this.settings});

  static Future<void> show(
    BuildContext context, {
    required DiscoverSettingsModel settings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlaceSheet(settings: settings),
    );
  }

  @override
  ConsumerState<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<PlaceSheet> {
  late final _controller = TextEditingController(
    text: widget.settings.currentPlace,
  );

  // Not awaited, like the genre save, so it still works offline.
  // A blank name clears the place.
  void _save(String? place) {
    final userId = ref.read(currentUidProvider).valueOrNull;
    if (userId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    unawaited(
      ref
          .read(discoverRepositoryProvider)
          .saveSettings(userId, widget.settings.withPlace(place))
          .catchError((Object e) {
            debugPrint('saveSettings failed: $e');
            messenger.showError("Couldn't save the place");
          }),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current = widget.settings.currentPlace;
    final recent = widget.settings.recentPlaces;

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
              Text('Where are you?', style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Books you scan are tagged with this place until you change it',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: current == null && recent.isEmpty,
                maxLength: DiscoverSettingsModel.maxPlaceLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Jaipur Book Fair',
                  prefixIcon: Icon(Icons.place_outlined),
                  counterText: '',
                ),
                onSubmitted: _save,
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Recent', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final place in recent)
                      ChoiceChip(
                        label: Text(place),
                        selected: place == current,
                        showCheckmark: false,
                        avatar: place == current
                            ? const Icon(
                                Icons.place_rounded,
                                size: 18,
                                color: AppColors.primaryDark,
                              )
                            : null,
                        onSelected: (_) => _save(place),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    // Nothing to clear when no place is set
                    onPressed: current == null ? null : () => _save(null),
                    child: const Text('No place'),
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => FilledButton(
                      onPressed: _controller.text.trim().isEmpty
                          ? null
                          : () => _save(_controller.text),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text('Set place'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
