import 'package:flutter/material.dart';
import 'package:shelf_snap/features/scanner/models/scan_mode.dart';

class ScanModeToggle extends StatelessWidget {
  final ScanMode mode;
  final ValueChanged<ScanMode> onChanged;

  const ScanModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton(
      segments: const [
        ButtonSegment(value: ScanMode.add, label: Text("Add")),
        ButtonSegment(value: ScanMode.discover, label: Text("Discover")),
      ],
      selected: {mode},
      onSelectionChanged: (set) => onChanged(set.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        foregroundColor: Colors.white,
        selectedForegroundColor: Colors.black,
        selectedBackgroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
      ),
    );
  }
}
