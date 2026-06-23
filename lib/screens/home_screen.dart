import 'package:flutter/material.dart';
import 'package:shelf_snap/models/nav_item_model.dart';
import 'package:shelf_snap/screens/scanner_screen.dart';
import 'package:shelf_snap/widgets/bottom_navbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  late final List<NavItemModel> navItems = [
    NavItemModel(
      page: const Center(child: Text("Home")),
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: "Home",
    ),
    NavItemModel(
      page: const Center(child: Text("Search")),
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
        MaterialPageRoute(builder: (context) => const ScannerScreen()),
      ),
    ),
    NavItemModel(
      page: const Center(child: Text("Tasks")),
      icon: Icons.bookmarks_outlined,
      activeIcon: Icons.bookmarks,
      label: "Library",
    ),
    NavItemModel(
      page: const Center(child: Text("Profile")),
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