import 'package:flutter/material.dart';

class ScannerEmptyState extends StatelessWidget {
  const ScannerEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_outlined, color: Colors.grey[700], size: 40),
          const SizedBox(height: 8),
          Text(
            'Point at a shelf and tap capture',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}