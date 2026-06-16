import 'package:flutter/material.dart';
import 'package:shelf_snap/screens/scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScannerScreen(),
                  ),
                );
              },
              child: Text("Open Scanner"),
            ),
          ),
        ],
      ),
    );
  }
}
