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
  // Lent, paused, busy states
  static const warning = Color(0xFFC98A1B);
  static const warningSoft = Color(0xFFFBF1DE);
  // Reading and other in-progress states
  static const accent = Color(0xFF3A6EA5);
  static const accentSoft = Color(0xFFE6EEF7);

  // Avatar colours as [text, background]; each user always gets the same pair
  static const avatarColors = <List<Color>>[
    [primary, primarySoft],
    [accent, accentSoft],
    [warning, warningSoft],
    [error, errorSoft],
  ];

  // Library banners: key to a photo in assets/banners/.
  // A library stores the key, so photos can be swapped without touching data.
  static const defaultBanner = 'banner-1';
  static const libraryBanners = <String, String>{
    'banner-1': 'assets/banners/banner-1.jpg',
    'banner-2': 'assets/banners/banner-2.jpg',
  };
}
