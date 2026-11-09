import 'package:flutter/material.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';

// Two pills over the camera in Discover mode: your genres and the current
// place. Both stay visible, so a place left on from yesterday gets noticed.
// Raw colours are fine here, like the rest of the scanner UI.
class DiscoverScanBar extends StatelessWidget {
  final DiscoverSettingsModel settings;
  final VoidCallback onGenres;
  final VoidCallback onPlace;

  const DiscoverScanBar({
    super.key,
    required this.settings,
    required this.onGenres,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    final count = settings.genres.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Pill(
            icon: Icons.local_offer_outlined,
            label: switch (count) {
              0 => 'Pick genres',
              1 => '1 genre',
              _ => '$count genres',
            },
            // White until genres are picked, since matching needs them
            highlight: count == 0,
            onTap: onGenres,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _Pill(
              icon: Icons.place_outlined,
              label: settings.currentPlace ?? 'Add place',
              onTap: onPlace,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _Pill({
    required this.icon,
    required this.label,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? Colors.black : Colors.white;

    return Material(
      color: highlight ? Colors.white : Colors.black54,
      shape: const StadiumBorder(side: BorderSide(color: Colors.white38)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: foreground),
                ),
              ),
              Icon(Icons.arrow_drop_down_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
