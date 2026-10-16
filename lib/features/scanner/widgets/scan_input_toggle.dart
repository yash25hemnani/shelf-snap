import 'package:flutter/material.dart';
import 'package:shelf_snap/features/scanner/models/scan_mode.dart';

class ScanInputToggle extends StatelessWidget {
  final ScanInput input;
  final ValueChanged<ScanInput> onChanged;

  const ScanInputToggle({
    super.key,
    required this.input,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ScanInput>(
      segments: [
        ButtonSegment(value: ScanInput.shelf, icon: Icon(Icons.photo_camera)),
        ButtonSegment(value: ScanInput.barcode, icon: Icon(Icons.qr_code)),
      ],
      selected: {input},
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
