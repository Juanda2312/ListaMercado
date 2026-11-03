import 'package:flutter/material.dart';

import 'supermarkets_screen.dart';
import 'products_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // P1 y P3 son placeholders hasta las Tareas 8 y 9.
  static const _pages = <Widget>[
    ProductsScreen(),
    SupermarketsScreen(),
    Placeholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
            label: 'Supermercados',
          ),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Lista'),
        ],
      ),
    );
  }
}
