import 'package:flutter/material.dart';

class BookCoverPlaceholder extends StatelessWidget {
  const BookCoverPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.book, color: Colors.grey, size: 20),
    );
  }
}