import 'package:flutter/material.dart';
import 'package:shelf_snap/features/discover/models/discover_settings_model.dart';

// Pills over the camera in Discover mode: your genres, your keywords and
// the current place. All stay visible, so a place left on from yesterday
// gets noticed. Raw colours are fine here, like the rest of the scanner UI.
class DiscoverScanBar extends StatelessWidget {
  final DiscoverSettingsModel settings;
  final VoidCallback onGenres;
  final VoidCallback onKeywords;
  final VoidCallback onPlace;

  const DiscoverScanBar({
    super.key,
    required this.settings,
    required this.onGenres,
    required this.onKeywords,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    final count = settings.genres.length;
    final keywords = settings.keywords.length;

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
          // Only a star (and a count once set), so three pills fit a
          // small phone and the place keeps room for its name
          _Pill(
            icon: keywords == 0
                ? Icons.star_outline_rounded
                : Icons.star_rounded,
            label: keywords == 0 ? null : '$keywords',
            tooltip: 'Your keywords',
            onTap: onKeywords,
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

// With a tooltip it's a compact pill: no dropdown arrow, label optional
class _Pill extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool highlight;
  final VoidCallback onTap;

  const _Pill({
    required this.icon,
    this.label,
    this.tooltip,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? Colors.black : Colors.white;
    final label = this.label;
    final tip = tooltip;
    final compact = tip != null;

    final pill = Material(
      color: highlight ? Colors.white : Colors.black54,
      shape: const StadiumBorder(side: BorderSide(color: Colors.white38)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, compact ? 12 : 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 24 tall, like the arrow, so every pill is the same height
              SizedBox(
                height: 24,
                child: Icon(icon, size: 18, color: foreground),
              ),
              if (label != null) ...[
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
              ],
              if (!compact)
                Icon(Icons.arrow_drop_down_rounded, color: foreground),
            ],
          ),
        ),
      ),
    );

    return tip == null ? pill : Tooltip(message: tip, child: pill);
  }
}
