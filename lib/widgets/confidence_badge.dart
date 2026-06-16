import 'package:flutter/material.dart';

class ConfidenceBadge extends StatelessWidget {
  final double score;

  const ConfidenceBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.6
        ? Colors.green[400]
        : score >= 0.4
        ? Colors.orange[400]
        : Colors.red[400];

    final label = score >= 0.6
        ? 'Strong'
        : score >= 0.4
        ? 'Possible'
        : 'Weak';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color ?? Colors.grey, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}