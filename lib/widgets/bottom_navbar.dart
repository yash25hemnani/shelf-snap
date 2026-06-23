import 'package:flutter/material.dart';
import 'package:shelf_snap/models/nav_item_model.dart';

class BottomNavbar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<NavItemModel> navItems;

  const BottomNavbar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.navItems,
  });

  @override
  Widget build(BuildContext context) {
    final centerIndex = (navItems.length / 2).floor();

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isCenter = index == centerIndex;

          if (isCenter) {
            return _CenterNavItem(
              icon: item.activeIcon,
              onTap: item.redirect ?? () => onTap(index),
            );
          }

          return _NavItem(
            icon: item.icon,
            activeIcon: item.activeIcon,
            label: item.label,
            selected: selectedIndex == index,
            onTap: () => onTap(index),
          );
        }).toList(),
      ),
    );
  }
}

// Big floating center button
class _CenterNavItem extends StatelessWidget {
  const _CenterNavItem({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

// Regular nav items with white ripple on tap
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white.withOpacity(0.3),   // white ripple
      highlightColor: Colors.white.withOpacity(0.1),
      child: SizedBox(
        width: 72,
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}