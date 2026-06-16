import 'package:flutter/material.dart';

/// A single piece of text detected by OCR, with its position in the image.
class ScannedTextBlock {
  final String text;
  final Rect boundingBox;

  ScannedTextBlock({required this.text, required this.boundingBox});

  @override
  String toString() => 'ScannedTextBlock("$text", $boundingBox)';
}