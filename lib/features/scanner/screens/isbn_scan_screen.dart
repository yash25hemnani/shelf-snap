import 'package:flutter/material.dart';
import 'package:shelf_snap/features/scanner/widgets/barcode_scanner_view.dart';

// Full-screen barcode scanner that closes with the first ISBN it reads,
// for filling an ISBN field
class IsbnScanScreen extends StatefulWidget {
  const IsbnScanScreen({super.key});

  @override
  State<IsbnScanScreen> createState() => _IsbnScanScreenState();
}

class _IsbnScanScreenState extends State<IsbnScanScreen> {
  // The camera keeps reporting the barcode, so only the first one pops
  bool _done = false;

  void _onIsbn(String isbn) {
    if (_done) return;
    _done = true;
    Navigator.pop(context, isbn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan the barcode'),
        titleTextStyle: Theme.of(context).textTheme.titleMedium,
        titleSpacing: 0,
      ),
      body: BarcodeScannerView(onIsbn: _onIsbn),
    );
  }
}
