import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF2F6B4F);
  static const primaryDark = Color(0xFF1F4A36);
  static const primarySoft = Color(0xFFE3EFE8);
  static const onPrimary = Color(0xFFFFFFFF);

  // Surfaces
  static const background = Color(0xFFFFFFFF);
  // Cards, fields, cover placeholders
  static const surfaceMuted = Color(0xFFF4F7F5);

  // Text
  static const text = Color(0xFF1B2B22);
  static const textSecondary = Color(0xFF5F6F66);
  static const hint = Color(0xFF9AA8A0);

  // Lines
  static const border = Color(0xFFE2E8E4);

  // Status, each with a soft tint for chip and banner backgrounds
  static const success = primary;
  static const successSoft = primarySoft;
  static const info = Color(0xFF4F5B55);
  static const infoSoft = Color(0xFFEEF1EF);
  static const error = Color(0xFFD64545);
  static const errorSoft = Color(0xFFFBEAEA);

  // Library banners: each entry is the start and end colour of a gradient.
  // A library stores the name, so entries can be reordered or restyled.
  static const defaultBanner = 'forest';
  static const libraryBanners = <String, List<Color>>{
    'forest': [Color(0xFF2F6B4F), Color(0xFF7FB89A)],
    'lake': [Color(0xFF1F4A6B), Color(0xFF7FA8C9)],
    'clay': [Color(0xFF8A4B2F), Color(0xFFE0A77F)],
    'dusk': [Color(0xFF5B3F8A), Color(0xFFB39BD9)],
    'honey': [Color(0xFF8A6A1F), Color(0xFFE3C46B)],
    'slate': [Color(0xFF3F4A45), Color(0xFF9AA8A0)],
  };
}
