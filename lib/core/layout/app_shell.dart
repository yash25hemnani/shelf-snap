import 'package:flutter/material.dart';
import 'package:shelf_snap/core/layout/bottom_navbar.dart';
import 'package:shelf_snap/core/layout/nav_item_model.dart';
import 'package:shelf_snap/features/home/screens/home_screen.dart';
import 'package:shelf_snap/features/library/screens/library_screen.dart';
import 'package:shelf_snap/features/profile/screens/profile_screen.dart';
import 'package:shelf_snap/features/scanner/screens/scanner_screen.dart';
import 'package:shelf_snap/features/search/screens/search_screen.dart';

// The signed-in app: the bottom navbar and the page for the selected tab
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  late final List<NavItemModel> navItems = [
    NavItemModel(
      // Switches tabs, so the navbar stays on screen
      page: HomeScreen(
        onOpenLibraries: () => setState(() {
          selectedIndex = navItems.indexWhere((i) => i.label == 'Library');
        }),
      ),
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: "Home",
    ),
    NavItemModel(
      page: SearchScreen(),
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: "Search",
    ),
    NavItemModel(
      page: const Center(child: Text("Add")),
      icon: Icons.document_scanner,
      activeIcon: Icons.document_scanner,
      label: "Scan",
      redirect: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ScannerScreen(),
          fullscreenDialog: true,
        ),
      ),
    ),
    NavItemModel(
      page: LibraryScreen(),
      icon: Icons.bookmarks_outlined,
      activeIcon: Icons.bookmarks,
      label: "Library",
    ),
    NavItemModel(
      page: const ProfileScreen(),
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: "Profile",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navItems[selectedIndex].page,
      bottomNavigationBar: BottomNavbar(
        selectedIndex: selectedIndex,
        onTap: (index) => setState(() {
          selectedIndex = index;
        }),
        navItems: navItems,
      ),
    );
  }
}
