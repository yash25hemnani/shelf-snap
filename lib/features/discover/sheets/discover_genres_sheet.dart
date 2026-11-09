import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf_snap/core/utils/snackbar.dart';
import 'package:shelf_snap/features/auth/providers/auth_provider.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';
import 'package:shelf_snap/features/discover/providers/discover_provider.dart';
import 'package:shelf_snap/features/library/models/genre.dart';
import 'package:shelf_snap/features/library/sheets/genre_picker_sheet.dart';

// Opens the genre picker for the reader's Discover taste and saves it.
// The save isn't awaited: Firestore applies it locally straight away, and
// an await would hang offline, e.g. in a crowded book fair hall.
Future<void> showDiscoverGenresSheet(
  BuildContext context,
  WidgetRef ref,
  DiscoverSettingsModel settings,
) async {
  final picked = await GenrePickerSheet.show(
    context,
    title: 'Your genres',
    subtitle: 'Books you scan in Discover are matched against these',
    selected: settings.genres.toSet(),
    actionLabel: 'Save genres',
  );
  if (picked == null || !context.mounted) return;

  final userId = ref.read(currentUidProvider).valueOrNull;
  if (userId == null) return;

  final messenger = ScaffoldMessenger.of(context);
  // Enum order, so the saved list doesn't depend on tap order
  final genres = Genre.values.where(picked.contains).toList();

  unawaited(
    ref
        .read(discoverRepositoryProvider)
        .saveSettings(userId, settings.copyWith(genres: genres))
        .catchError((Object e) {
          debugPrint('saveSettings failed: $e');
          messenger.showError("Couldn't save your genres");
        }),
  );
}
