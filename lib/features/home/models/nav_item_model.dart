import 'package:flutter/material.dart';

class NavItemModel {
  final Widget page;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback? redirect;

  const NavItemModel({
    required this.page,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.redirect,
  });
}